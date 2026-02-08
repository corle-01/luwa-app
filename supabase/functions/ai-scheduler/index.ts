// =================================================================
// UTTER APP - AI Scheduler Edge Function
// Cron job handler - runs every hour for proactive AI checks
// =================================================================

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// --------------- CORS ---------------
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// --------------- Types ---------------
interface SchedulerResult {
  outlet_id: string;
  outlet_name: string;
  checks: {
    low_stock: CheckResult;
    demand_forecast: CheckResult;
    anomaly_detection: CheckResult;
    pricing_opportunities: CheckResult;
  };
}

interface CheckResult {
  status: "ok" | "warning" | "error";
  insights_created: number;
  actions_taken: number;
  details: string;
}

// --------------- Trust Level Helper ---------------
async function getTrustLevel(
  supabase: SupabaseClient,
  outletId: string,
  featureKey: string
): Promise<number> {
  const { data } = await supabase
    .from("ai_trust_settings")
    .select("trust_level, is_enabled")
    .eq("outlet_id", outletId)
    .eq("feature_key", featureKey)
    .single();

  if (!data || !data.is_enabled) return -1;
  return data.trust_level;
}

// --------------- CHECK 1: Low Stock Alerts ---------------
async function checkLowStock(
  supabase: SupabaseClient,
  outletId: string
): Promise<CheckResult> {
  let insightsCreated = 0;
  let actionsTaken = 0;

  try {
    // Query low_stock_alerts view for this outlet
    const { data: alerts, error } = await supabase
      .from("low_stock_alerts")
      .select("*")
      .eq("outlet_id", outletId)
      .in("stock_status", ["out_of_stock", "low_stock"]);

    if (error) throw error;
    if (!alerts || alerts.length === 0) {
      return { status: "ok", insights_created: 0, actions_taken: 0, details: "Semua stok aman" };
    }

    const outOfStock = alerts.filter((a) => a.stock_status === "out_of_stock");
    const lowStock = alerts.filter((a) => a.stock_status === "low_stock");

    // Create insight for out-of-stock items
    if (outOfStock.length > 0) {
      const itemNames = outOfStock.map((a) => a.name).join(", ");
      await supabase.from("ai_insights").insert({
        outlet_id: outletId,
        insight_type: "stock_prediction",
        title: `${outOfStock.length} bahan baku habis!`,
        description: `Bahan baku berikut sudah habis dan perlu segera di-restock: ${itemNames}`,
        severity: "critical",
        data: {
          items: outOfStock.map((a) => ({
            id: a.id,
            name: a.name,
            unit: a.unit,
            current_stock: a.current_stock,
            supplier_name: a.supplier_name,
            supplier_id: a.supplier_id,
          })),
        },
        suggested_action: {
          type: "create_purchase_order",
          description: "Buat PO untuk restock bahan baku yang habis",
          items: outOfStock.map((a) => ({
            ingredient_id: a.id,
            name: a.name,
            suggested_quantity: Number(a.max_stock) - Number(a.current_stock),
            supplier_id: a.supplier_id,
          })),
        },
        status: "active",
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      });
      insightsCreated++;
    }

    // Create insight for low stock items
    if (lowStock.length > 0) {
      const itemNames = lowStock.map((a) => `${a.name} (${a.current_stock} ${a.unit})`).join(", ");
      await supabase.from("ai_insights").insert({
        outlet_id: outletId,
        insight_type: "stock_prediction",
        title: `${lowStock.length} bahan baku hampir habis`,
        description: `Stok menipis: ${itemNames}`,
        severity: "warning",
        data: {
          items: lowStock.map((a) => ({
            id: a.id,
            name: a.name,
            unit: a.unit,
            current_stock: Number(a.current_stock),
            min_stock: Number(a.min_stock),
            supplier_name: a.supplier_name,
            supplier_id: a.supplier_id,
          })),
        },
        suggested_action: {
          type: "create_purchase_order",
          description: "Pertimbangkan untuk restock bahan baku yang hampir habis",
          items: lowStock.map((a) => ({
            ingredient_id: a.id,
            name: a.name,
            suggested_quantity: Number(a.max_stock) - Number(a.current_stock),
            supplier_id: a.supplier_id,
          })),
        },
        status: "active",
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      });
      insightsCreated++;
    }

    // Auto-disable products if trust level >= 2 and ingredients are out of stock
    const trustLevel = await getTrustLevel(supabase, outletId, "auto_disable_product");
    if (trustLevel >= 2 && outOfStock.length > 0) {
      // Find products that use out-of-stock ingredients
      const outOfStockIds = outOfStock.map((a) => a.id);

      const { data: recipes } = await supabase
        .from("recipes")
        .select("product_id, ingredient_id")
        .in("ingredient_id", outOfStockIds);

      if (recipes && recipes.length > 0) {
        const productIds = [...new Set(recipes.map((r) => r.product_id))];

        // Get product names for logging
        const { data: products } = await supabase
          .from("products")
          .select("id, name")
          .in("id", productIds)
          .eq("outlet_id", outletId)
          .eq("is_available", true);

        if (products && products.length > 0) {
          const idsToDisable = products.map((p) => p.id);

          const { error: updateErr } = await supabase
            .from("products")
            .update({ is_available: false })
            .in("id", idsToDisable)
            .eq("outlet_id", outletId);

          if (!updateErr) {
            actionsTaken += products.length;
            const productNames = products.map((p) => p.name).join(", ");

            // Log the action
            await supabase.from("ai_action_logs").insert({
              outlet_id: outletId,
              feature_key: "auto_disable_product",
              trust_level: trustLevel,
              action_type: "auto_executed",
              action_description: `Menonaktifkan ${products.length} produk karena bahan baku habis: ${productNames}`,
              action_data: {
                disabled_products: products.map((p) => ({ id: p.id, name: p.name })),
                out_of_stock_ingredients: outOfStock.map((a) => ({ id: a.id, name: a.name })),
              },
              source: "scheduler",
              undo_deadline: new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString(),
            });
          }
        }
      }
    }

    return {
      status: "warning",
      insights_created: insightsCreated,
      actions_taken: actionsTaken,
      details: `${outOfStock.length} habis, ${lowStock.length} menipis. ${actionsTaken} produk dinonaktifkan otomatis.`,
    };
  } catch (err) {
    console.error(`[LOW STOCK] Outlet ${outletId}:`, err);
    return {
      status: "error",
      insights_created: insightsCreated,
      actions_taken: actionsTaken,
      details: `Error: ${(err as Error).message}`,
    };
  }
}

// --------------- CHECK 2: Demand Forecasting ---------------
async function checkDemandForecast(
  supabase: SupabaseClient,
  outletId: string
): Promise<CheckResult> {
  let insightsCreated = 0;
  let actionsTaken = 0;

  try {
    const lookbackDays = 14;
    const since = new Date();
    since.setDate(since.getDate() - lookbackDays);

    // Get stock movements (usage) for last 14 days
    const { data: movements, error: moveErr } = await supabase
      .from("stock_movements")
      .select("ingredient_id, quantity, movement_type, created_at")
      .eq("outlet_id", outletId)
      .in("movement_type", ["auto_deduct", "stock_out", "waste"])
      .gte("created_at", since.toISOString());

    if (moveErr) throw moveErr;

    // Get all active ingredients
    const { data: ingredients, error: ingrErr } = await supabase
      .from("ingredients")
      .select("id, name, unit, current_stock, min_stock, max_stock, cost_per_unit, supplier_id")
      .eq("outlet_id", outletId)
      .eq("is_active", true);

    if (ingrErr) throw ingrErr;
    if (!ingredients || ingredients.length === 0) {
      return { status: "ok", insights_created: 0, actions_taken: 0, details: "Tidak ada bahan baku aktif" };
    }

    // Calculate average daily usage per ingredient
    const usageMap: Record<string, number> = {};
    for (const m of movements || []) {
      const id = m.ingredient_id;
      if (!usageMap[id]) usageMap[id] = 0;
      usageMap[id] += Math.abs(Number(m.quantity));
    }

    // Find items that will run out within 3 days
    const criticalItems: Array<{
      ingredient_id: string;
      name: string;
      unit: string;
      current_stock: number;
      avg_daily_usage: number;
      days_until_empty: number;
      suggested_order_qty: number;
      supplier_id: string | null;
      cost_per_unit: number;
    }> = [];

    for (const ing of ingredients) {
      const totalUsage = usageMap[ing.id] || 0;
      const avgDailyUsage = totalUsage / lookbackDays;

      if (avgDailyUsage <= 0) continue;

      const currentStock = Number(ing.current_stock);
      const daysUntilEmpty = Math.floor(currentStock / avgDailyUsage);

      if (daysUntilEmpty <= 3) {
        // Suggest ordering enough for 7 days + buffer to max_stock
        const suggestedQty = Math.max(
          avgDailyUsage * 7 - currentStock + Number(ing.min_stock),
          Number(ing.max_stock) - currentStock
        );

        criticalItems.push({
          ingredient_id: ing.id,
          name: ing.name,
          unit: ing.unit,
          current_stock: currentStock,
          avg_daily_usage: Math.round(avgDailyUsage * 100) / 100,
          days_until_empty: daysUntilEmpty,
          suggested_order_qty: Math.round(Math.max(0, suggestedQty) * 100) / 100,
          supplier_id: ing.supplier_id,
          cost_per_unit: Number(ing.cost_per_unit),
        });
      }
    }

    if (criticalItems.length === 0) {
      return { status: "ok", insights_created: 0, actions_taken: 0, details: "Semua stok cukup untuk 3+ hari ke depan" };
    }

    // Create insight for critical items
    const itemSummary = criticalItems
      .map((i) => `${i.name} (~${i.days_until_empty} hari lagi)`)
      .join(", ");

    await supabase.from("ai_insights").insert({
      outlet_id: outletId,
      insight_type: "demand_forecast",
      title: `${criticalItems.length} bahan baku akan habis dalam 3 hari`,
      description: `Berdasarkan pola penggunaan 14 hari terakhir, bahan baku berikut diprediksi akan habis segera: ${itemSummary}`,
      severity: "warning",
      data: {
        lookback_days: lookbackDays,
        critical_items: criticalItems,
      },
      suggested_action: {
        type: "create_purchase_order",
        description: "Buat PO untuk restock bahan baku yang akan habis",
        items: criticalItems.map((i) => ({
          ingredient_id: i.ingredient_id,
          name: i.name,
          quantity: i.suggested_order_qty,
          unit: i.unit,
          supplier_id: i.supplier_id,
        })),
      },
      status: "active",
      expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    });
    insightsCreated++;

    // Auto-create PO if trust level >= 2
    const trustLevel = await getTrustLevel(supabase, outletId, "auto_reorder");
    if (trustLevel >= 2 && criticalItems.length > 0) {
      // Group by supplier
      const bySupplier: Record<string, typeof criticalItems> = {};
      for (const item of criticalItems) {
        const supplierId = item.supplier_id || "no_supplier";
        if (!bySupplier[supplierId]) bySupplier[supplierId] = [];
        bySupplier[supplierId].push(item);
      }

      for (const [supplierId, items] of Object.entries(bySupplier)) {
        if (supplierId === "no_supplier") continue;

        // Generate PO number
        const { data: poNumData } = await supabase.rpc("generate_po_number", {
          p_outlet_id: outletId,
        });
        const poNumber = poNumData || `PO-AUTO-${Date.now()}`;

        const totalAmount = items.reduce(
          (s, i) => s + i.suggested_order_qty * i.cost_per_unit,
          0
        );

        // Create PO
        const { data: po, error: poErr } = await supabase
          .from("purchase_orders")
          .insert({
            outlet_id: outletId,
            supplier_id: supplierId,
            po_number: poNumber,
            status: "draft",
            total_amount: totalAmount,
            notes: `Auto-generated by AI Scheduler - Demand Forecast (${criticalItems.length} items predicted to run out in <=3 days)`,
            expected_date: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString().split("T")[0],
          })
          .select("id")
          .single();

        if (poErr) {
          console.error(`[DEMAND] Failed to create PO for supplier ${supplierId}:`, poErr);
          continue;
        }

        // Create PO items
        const poItems = items.map((item) => ({
          purchase_order_id: po.id,
          ingredient_id: item.ingredient_id,
          quantity_ordered: item.suggested_order_qty,
          unit_cost: item.cost_per_unit,
          total_cost: item.suggested_order_qty * item.cost_per_unit,
          notes: `Avg usage: ${item.avg_daily_usage} ${item.unit}/day, est. ${item.days_until_empty} days left`,
        }));

        await supabase.from("purchase_order_items").insert(poItems);
        actionsTaken++;

        // Log action
        await supabase.from("ai_action_logs").insert({
          outlet_id: outletId,
          feature_key: "auto_reorder",
          trust_level: trustLevel,
          action_type: "auto_executed",
          action_description: `Auto-create PO ${poNumber} untuk ${items.length} bahan baku yang diprediksi habis dalam 3 hari (total Rp ${Math.round(totalAmount).toLocaleString("id-ID")})`,
          action_data: {
            po_id: po.id,
            po_number: poNumber,
            supplier_id: supplierId,
            items: items.map((i) => ({
              name: i.name,
              qty: i.suggested_order_qty,
              days_left: i.days_until_empty,
            })),
            total_amount: totalAmount,
          },
          source: "scheduler",
          undo_deadline: new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString(),
        });
      }
    }

    return {
      status: "warning",
      insights_created: insightsCreated,
      actions_taken: actionsTaken,
      details: `${criticalItems.length} bahan baku diprediksi habis dalam 3 hari. ${actionsTaken} PO auto-created.`,
    };
  } catch (err) {
    console.error(`[DEMAND FORECAST] Outlet ${outletId}:`, err);
    return {
      status: "error",
      insights_created: insightsCreated,
      actions_taken: actionsTaken,
      details: `Error: ${(err as Error).message}`,
    };
  }
}

// --------------- CHECK 3: Anomaly Detection ---------------
async function checkAnomalies(
  supabase: SupabaseClient,
  outletId: string
): Promise<CheckResult> {
  let insightsCreated = 0;
  const actionsTaken = 0;

  try {
    const now = new Date();
    const todayStart = new Date(now);
    todayStart.setHours(0, 0, 0, 0);

    const thirtyDaysAgo = new Date(now);
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // Get today's voids and refunds
    const { data: todayVoids, error: todayErr } = await supabase
      .from("orders")
      .select("id, status, total")
      .eq("outlet_id", outletId)
      .in("status", ["cancelled", "refunded"])
      .gte("created_at", todayStart.toISOString());

    if (todayErr) throw todayErr;

    // Get 30-day baseline voids and refunds
    const { data: baselineVoids, error: baseErr } = await supabase
      .from("orders")
      .select("id, status, total")
      .eq("outlet_id", outletId)
      .in("status", ["cancelled", "refunded"])
      .gte("created_at", thirtyDaysAgo.toISOString())
      .lt("created_at", todayStart.toISOString());

    if (baseErr) throw baseErr;

    const todayCount = (todayVoids || []).length;
    const todayTotal = (todayVoids || []).reduce((s, o) => s + Number(o.total), 0);
    const baselineCount = (baselineVoids || []).length;
    const baselineDays = 30;
    const avgDailyVoids = baselineCount / baselineDays;
    const avgDailyVoidAmount = (baselineVoids || []).reduce((s, o) => s + Number(o.total), 0) / baselineDays;

    // Check if today's voids are > 2.5x the 30-day average
    const ratio = avgDailyVoids > 0 ? todayCount / avgDailyVoids : 0;
    const isAnomaly = ratio > 2.5;

    if (isAnomaly) {
      const voidsByStatus = {
        cancelled: (todayVoids || []).filter((o) => o.status === "cancelled").length,
        refunded: (todayVoids || []).filter((o) => o.status === "refunded").length,
      };

      await supabase.from("ai_insights").insert({
        outlet_id: outletId,
        insight_type: "anomaly",
        title: `Void/refund hari ini ${ratio.toFixed(1)}x lebih tinggi dari rata-rata!`,
        description: `Hari ini sudah ada ${todayCount} void/refund (Rp ${Math.round(todayTotal).toLocaleString("id-ID")}), sedangkan rata-rata 30 hari terakhir hanya ${avgDailyVoids.toFixed(1)} per hari (Rp ${Math.round(avgDailyVoidAmount).toLocaleString("id-ID")}). Cancelled: ${voidsByStatus.cancelled}, Refunded: ${voidsByStatus.refunded}. Mohon dicek apakah ada masalah operasional.`,
        severity: ratio > 5 ? "critical" : "warning",
        data: {
          today_count: todayCount,
          today_total: todayTotal,
          avg_daily_count: Math.round(avgDailyVoids * 10) / 10,
          avg_daily_amount: Math.round(avgDailyVoidAmount),
          ratio: Math.round(ratio * 100) / 100,
          voids_by_status: voidsByStatus,
        },
        suggested_action: {
          type: "investigate",
          description: "Periksa log void/refund hari ini untuk mencari pola atau masalah",
        },
        status: "active",
        expires_at: new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString(),
      });
      insightsCreated++;

      // Log for visibility
      const trustLevel = await getTrustLevel(supabase, outletId, "anomaly_alert");
      await supabase.from("ai_action_logs").insert({
        outlet_id: outletId,
        feature_key: "anomaly_alert",
        trust_level: trustLevel,
        action_type: "informed",
        action_description: `Anomali terdeteksi: ${todayCount} void/refund hari ini (${ratio.toFixed(1)}x rata-rata). Total: Rp ${Math.round(todayTotal).toLocaleString("id-ID")}`,
        action_data: {
          today_count: todayCount,
          today_total: todayTotal,
          avg_daily: avgDailyVoids,
          ratio,
        },
        source: "scheduler",
      });

      return {
        status: "warning",
        insights_created: insightsCreated,
        actions_taken: actionsTaken,
        details: `Anomali: ${todayCount} voids hari ini (${ratio.toFixed(1)}x rata-rata ${avgDailyVoids.toFixed(1)}/hari)`,
      };
    }

    return {
      status: "ok",
      insights_created: 0,
      actions_taken: 0,
      details: `Void/refund hari ini: ${todayCount} (rata-rata: ${avgDailyVoids.toFixed(1)}/hari) - Normal`,
    };
  } catch (err) {
    console.error(`[ANOMALY] Outlet ${outletId}:`, err);
    return {
      status: "error",
      insights_created: insightsCreated,
      actions_taken: actionsTaken,
      details: `Error: ${(err as Error).message}`,
    };
  }
}

// --------------- CHECK 4: Pricing Opportunities ---------------
async function checkPricingOpportunities(
  supabase: SupabaseClient,
  outletId: string
): Promise<CheckResult> {
  let insightsCreated = 0;
  const actionsTaken = 0;

  try {
    // Get products with HPP data
    const { data: products, error: prodErr } = await supabase
      .from("product_hpp_summary")
      .select("*")
      .eq("outlet_id", outletId);

    if (prodErr) throw prodErr;
    if (!products || products.length === 0) {
      return { status: "ok", insights_created: 0, actions_taken: 0, details: "Tidak ada data produk" };
    }

    // Find low-margin products (< 20%)
    const lowMarginProducts = products.filter(
      (p) => Number(p.profit_percent) < 20 && Number(p.hpp) > 0
    );

    if (lowMarginProducts.length === 0) {
      return { status: "ok", insights_created: 0, actions_taken: 0, details: "Semua margin produk >= 20%" };
    }

    // Check sales volume for the last 7 days to find high-volume low-margin items
    const weekAgo = new Date();
    weekAgo.setDate(weekAgo.getDate() - 7);

    const { data: salesData } = await supabase
      .from("order_items")
      .select(`
        product_id,
        quantity,
        order:orders!inner(outlet_id, status, created_at)
      `)
      .eq("order.outlet_id", outletId)
      .eq("order.status", "completed")
      .gte("order.created_at", weekAgo.toISOString());

    // Build sales volume map
    const salesVolume: Record<string, number> = {};
    for (const item of salesData || []) {
      if (!salesVolume[item.product_id]) salesVolume[item.product_id] = 0;
      salesVolume[item.product_id] += item.quantity;
    }

    // Find products with < 20% margin AND high volume (10+ per week)
    const opportunities = lowMarginProducts
      .filter((p) => (salesVolume[p.product_id] || 0) >= 10)
      .map((p) => {
        const hpp = Number(p.hpp);
        const currentPrice = Number(p.selling_price);
        const currentMargin = Number(p.profit_percent);
        const weeklyVolume = salesVolume[p.product_id] || 0;
        // Suggest price for 30% margin, rounded up to nearest 500
        const suggestedPrice = Math.ceil(hpp / 0.7 / 500) * 500;
        const weeklyProfitIncrease = (suggestedPrice - currentPrice) * weeklyVolume;

        return {
          product_id: p.product_id,
          product_name: p.product_name,
          category: p.category_name,
          current_price: currentPrice,
          hpp,
          current_margin: currentMargin,
          weekly_volume: weeklyVolume,
          suggested_price: suggestedPrice,
          suggested_margin: Math.round(((suggestedPrice - hpp) / suggestedPrice) * 100 * 10) / 10,
          price_increase: suggestedPrice - currentPrice,
          est_weekly_profit_increase: weeklyProfitIncrease,
        };
      })
      .sort((a, b) => b.est_weekly_profit_increase - a.est_weekly_profit_increase);

    if (opportunities.length === 0) {
      return {
        status: "ok",
        insights_created: 0,
        actions_taken: 0,
        details: `${lowMarginProducts.length} produk margin rendah, tapi tidak ada yang volume tinggi`,
      };
    }

    // Calculate total potential weekly profit increase
    const totalWeeklyIncrease = opportunities.reduce(
      (s, o) => s + o.est_weekly_profit_increase,
      0
    );

    const topItems = opportunities.slice(0, 5);
    const itemDescriptions = topItems
      .map(
        (o) =>
          `${o.product_name} (margin ${o.current_margin}%, suggest Rp ${o.suggested_price.toLocaleString("id-ID")})`
      )
      .join("; ");

    await supabase.from("ai_insights").insert({
      outlet_id: outletId,
      insight_type: "pricing_suggestion",
      title: `${opportunities.length} produk bisa naikkan margin (potensi +Rp ${Math.round(totalWeeklyIncrease).toLocaleString("id-ID")}/minggu)`,
      description: `Ditemukan ${opportunities.length} produk dengan margin < 20% tapi volume jual tinggi (10+/minggu). Kenaikan harga kecil bisa meningkatkan profit signifikan. Top picks: ${itemDescriptions}`,
      severity: "positive",
      data: {
        opportunities,
        total_weekly_profit_increase: totalWeeklyIncrease,
        total_monthly_profit_increase: totalWeeklyIncrease * 4,
      },
      suggested_action: {
        type: "update_product_price",
        description: `Naikkan harga ${opportunities.length} produk untuk target margin 30%`,
        items: opportunities.map((o) => ({
          product_id: o.product_id,
          product_name: o.product_name,
          current_price: o.current_price,
          suggested_price: o.suggested_price,
        })),
      },
      status: "active",
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    });
    insightsCreated++;

    // Log action
    const trustLevel = await getTrustLevel(supabase, outletId, "pricing_recommendation");
    await supabase.from("ai_action_logs").insert({
      outlet_id: outletId,
      feature_key: "pricing_recommendation",
      trust_level: trustLevel,
      action_type: "suggested",
      action_description: `Menemukan ${opportunities.length} produk yang bisa naikkan margin. Potensi tambahan profit: Rp ${Math.round(totalWeeklyIncrease).toLocaleString("id-ID")}/minggu`,
      action_data: {
        opportunity_count: opportunities.length,
        total_weekly_increase: totalWeeklyIncrease,
        top_items: topItems,
      },
      source: "scheduler",
    });

    return {
      status: "ok",
      insights_created: insightsCreated,
      actions_taken: actionsTaken,
      details: `${opportunities.length} pricing opportunities found. Potential +Rp ${Math.round(totalWeeklyIncrease).toLocaleString("id-ID")}/week`,
    };
  } catch (err) {
    console.error(`[PRICING] Outlet ${outletId}:`, err);
    return {
      status: "error",
      insights_created: insightsCreated,
      actions_taken: actionsTaken,
      details: `Error: ${(err as Error).message}`,
    };
  }
}

// --------------- Main Handler ---------------
serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log("[AI SCHEDULER] Starting hourly check...");
    const startTime = Date.now();

    // Get all active outlets
    const { data: outlets, error: outletErr } = await supabase
      .from("outlets")
      .select("id, name")
      .eq("is_active", true);

    if (outletErr) throw outletErr;
    if (!outlets || outlets.length === 0) {
      return new Response(
        JSON.stringify({ message: "No active outlets found", results: [] }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[AI SCHEDULER] Processing ${outlets.length} active outlets...`);

    const results: SchedulerResult[] = [];

    // Process each outlet
    for (const outlet of outlets) {
      console.log(`[AI SCHEDULER] Processing outlet: ${outlet.name} (${outlet.id})`);

      try {
        // Expire old active insights (older than their expiry date)
        await supabase
          .from("ai_insights")
          .update({ status: "expired" })
          .eq("outlet_id", outlet.id)
          .eq("status", "active")
          .lt("expires_at", new Date().toISOString());

        // Run all 4 checks in parallel
        const [lowStock, demandForecast, anomalyDetection, pricingOpportunities] =
          await Promise.all([
            checkLowStock(supabase, outlet.id),
            checkDemandForecast(supabase, outlet.id),
            checkAnomalies(supabase, outlet.id),
            checkPricingOpportunities(supabase, outlet.id),
          ]);

        results.push({
          outlet_id: outlet.id,
          outlet_name: outlet.name,
          checks: {
            low_stock: lowStock,
            demand_forecast: demandForecast,
            anomaly_detection: anomalyDetection,
            pricing_opportunities: pricingOpportunities,
          },
        });
      } catch (outletErr) {
        console.error(`[AI SCHEDULER] Error processing outlet ${outlet.name}:`, outletErr);
        results.push({
          outlet_id: outlet.id,
          outlet_name: outlet.name,
          checks: {
            low_stock: { status: "error", insights_created: 0, actions_taken: 0, details: "Skipped due to error" },
            demand_forecast: { status: "error", insights_created: 0, actions_taken: 0, details: "Skipped due to error" },
            anomaly_detection: { status: "error", insights_created: 0, actions_taken: 0, details: "Skipped due to error" },
            pricing_opportunities: { status: "error", insights_created: 0, actions_taken: 0, details: "Skipped due to error" },
          },
        });
      }
    }

    const duration = Date.now() - startTime;

    // Summary
    const totalInsights = results.reduce(
      (s, r) =>
        s +
        r.checks.low_stock.insights_created +
        r.checks.demand_forecast.insights_created +
        r.checks.anomaly_detection.insights_created +
        r.checks.pricing_opportunities.insights_created,
      0
    );

    const totalActions = results.reduce(
      (s, r) =>
        s +
        r.checks.low_stock.actions_taken +
        r.checks.demand_forecast.actions_taken +
        r.checks.anomaly_detection.actions_taken +
        r.checks.pricing_opportunities.actions_taken,
      0
    );

    console.log(
      `[AI SCHEDULER] Complete. ${outlets.length} outlets, ${totalInsights} insights, ${totalActions} actions, ${duration}ms`
    );

    return new Response(
      JSON.stringify({
        success: true,
        outlets_processed: outlets.length,
        total_insights_created: totalInsights,
        total_actions_taken: totalActions,
        duration_ms: duration,
        results,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("[AI SCHEDULER] Fatal error:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
