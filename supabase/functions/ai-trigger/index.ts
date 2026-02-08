// =================================================================
// UTTER APP - AI Trigger Edge Function
// Event-driven trigger handler for real-time AI responses
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
interface TriggerPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: Record<string, unknown>;
  old_record: Record<string, unknown> | null;
}

interface TriggerResult {
  trigger_type: string;
  actions_taken: string[];
  insights_created: number;
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

// --------------- Helper: Auto-Disable Products ---------------
// When an ingredient stock reaches 0, disable all products that use it
async function autoDisableProducts(
  supabase: SupabaseClient,
  outletId: string,
  ingredientId: string,
  ingredientName: string
): Promise<{ disabled: string[]; actionLogged: boolean }> {
  const disabled: string[] = [];
  let actionLogged = false;

  try {
    // Check trust level
    const trustLevel = await getTrustLevel(supabase, outletId, "auto_disable_product");
    if (trustLevel < 2) {
      // Not enough trust level - only create insight, don't auto-disable
      await supabase.from("ai_insights").insert({
        outlet_id: outletId,
        insight_type: "stock_prediction",
        title: `Bahan baku "${ingredientName}" habis!`,
        description: `Stok ${ingredientName} sudah habis (0). Beberapa produk mungkin tidak bisa dibuat. Pertimbangkan untuk menonaktifkan produk terkait dan segera restock.`,
        severity: "critical",
        data: {
          ingredient_id: ingredientId,
          ingredient_name: ingredientName,
          trust_level: trustLevel,
          auto_action: false,
        },
        suggested_action: {
          type: "disable_products",
          description: `Nonaktifkan produk yang menggunakan ${ingredientName} dan buat PO restock`,
        },
        status: "active",
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      });

      // Log as informed
      await supabase.from("ai_action_logs").insert({
        outlet_id: outletId,
        feature_key: "auto_disable_product",
        trust_level: trustLevel,
        action_type: "informed",
        action_description: `Bahan baku "${ingredientName}" habis. Trust level (${trustLevel}) kurang untuk auto-disable (perlu >= 2).`,
        action_data: { ingredient_id: ingredientId, ingredient_name: ingredientName },
        source: "trigger",
      });

      return { disabled, actionLogged: true };
    }

    // Trust level >= 2 - auto-disable products
    // Find all products using this ingredient via recipes
    const { data: recipes, error: recipeErr } = await supabase
      .from("recipes")
      .select("product_id")
      .eq("ingredient_id", ingredientId);

    if (recipeErr || !recipes || recipes.length === 0) {
      return { disabled, actionLogged: false };
    }

    const productIds = [...new Set(recipes.map((r) => r.product_id))];

    // Get currently available products
    const { data: products, error: prodErr } = await supabase
      .from("products")
      .select("id, name")
      .in("id", productIds)
      .eq("outlet_id", outletId)
      .eq("is_available", true);

    if (prodErr || !products || products.length === 0) {
      return { disabled, actionLogged: false };
    }

    // Disable these products
    const idsToDisable = products.map((p) => p.id);
    const { error: updateErr } = await supabase
      .from("products")
      .update({ is_available: false })
      .in("id", idsToDisable)
      .eq("outlet_id", outletId);

    if (updateErr) {
      console.error("[TRIGGER] Failed to disable products:", updateErr);
      return { disabled, actionLogged: false };
    }

    const disabledNames = products.map((p) => p.name);
    disabled.push(...disabledNames);

    // Create insight
    await supabase.from("ai_insights").insert({
      outlet_id: outletId,
      insight_type: "stock_prediction",
      title: `${products.length} produk dinonaktifkan otomatis`,
      description: `Bahan baku "${ingredientName}" habis. Produk berikut telah dinonaktifkan otomatis: ${disabledNames.join(", ")}. Produk akan diaktifkan kembali setelah stok diisi ulang.`,
      severity: "warning",
      data: {
        ingredient_id: ingredientId,
        ingredient_name: ingredientName,
        disabled_products: products.map((p) => ({ id: p.id, name: p.name })),
        auto_action: true,
      },
      suggested_action: {
        type: "restock",
        description: `Segera restock ${ingredientName} untuk mengaktifkan kembali produk`,
      },
      status: "active",
      expires_at: new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString(),
    });

    // Log action
    await supabase.from("ai_action_logs").insert({
      outlet_id: outletId,
      feature_key: "auto_disable_product",
      trust_level: trustLevel,
      action_type: "auto_executed",
      action_description: `Menonaktifkan ${products.length} produk karena "${ingredientName}" habis: ${disabledNames.join(", ")}`,
      action_data: {
        ingredient_id: ingredientId,
        ingredient_name: ingredientName,
        disabled_products: products.map((p) => ({ id: p.id, name: p.name })),
      },
      source: "trigger",
      undo_deadline: new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString(),
    });
    actionLogged = true;

    return { disabled, actionLogged };
  } catch (err) {
    console.error("[TRIGGER] autoDisableProducts error:", err);
    return { disabled, actionLogged };
  }
}

// --------------- Helper: Auto-Enable Products ---------------
// When an ingredient stock is replenished (was 0, now > 0), re-enable products
async function autoEnableProducts(
  supabase: SupabaseClient,
  outletId: string,
  ingredientId: string,
  ingredientName: string
): Promise<{ enabled: string[]; actionLogged: boolean }> {
  const enabled: string[] = [];
  let actionLogged = false;

  try {
    // Check trust level
    const trustLevel = await getTrustLevel(supabase, outletId, "auto_enable_product");
    if (trustLevel < 2) {
      // Only inform, don't auto-enable
      await supabase.from("ai_insights").insert({
        outlet_id: outletId,
        insight_type: "stock_prediction",
        title: `Stok "${ingredientName}" sudah diisi ulang!`,
        description: `Stok ${ingredientName} sudah tersedia kembali. Pertimbangkan untuk mengaktifkan kembali produk yang menggunakan bahan baku ini.`,
        severity: "positive",
        data: {
          ingredient_id: ingredientId,
          ingredient_name: ingredientName,
          trust_level: trustLevel,
          auto_action: false,
        },
        suggested_action: {
          type: "enable_products",
          description: `Aktifkan kembali produk yang menggunakan ${ingredientName}`,
        },
        status: "active",
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      });

      await supabase.from("ai_action_logs").insert({
        outlet_id: outletId,
        feature_key: "auto_enable_product",
        trust_level: trustLevel,
        action_type: "informed",
        action_description: `Stok "${ingredientName}" diisi ulang. Trust level (${trustLevel}) kurang untuk auto-enable (perlu >= 2).`,
        action_data: { ingredient_id: ingredientId, ingredient_name: ingredientName },
        source: "trigger",
      });

      return { enabled, actionLogged: true };
    }

    // Trust level >= 2 - auto-enable products
    // Find products using this ingredient
    const { data: recipes, error: recipeErr } = await supabase
      .from("recipes")
      .select("product_id")
      .eq("ingredient_id", ingredientId);

    if (recipeErr || !recipes || recipes.length === 0) {
      return { enabled, actionLogged: false };
    }

    const productIds = [...new Set(recipes.map((r) => r.product_id))];

    // For each product, check if ALL its ingredients now have stock > 0
    const productsToEnable: Array<{ id: string; name: string }> = [];

    for (const productId of productIds) {
      // Get product info
      const { data: product } = await supabase
        .from("products")
        .select("id, name, is_available")
        .eq("id", productId)
        .eq("outlet_id", outletId)
        .eq("is_available", false)
        .single();

      if (!product) continue; // Product already available or not found

      // Get all ingredients for this product
      const { data: productRecipes } = await supabase
        .from("recipes")
        .select("ingredient_id")
        .eq("product_id", productId);

      if (!productRecipes || productRecipes.length === 0) continue;

      // Check if all ingredients have stock > 0
      const ingredientIds = productRecipes.map((r) => r.ingredient_id);
      const { data: ingredients } = await supabase
        .from("ingredients")
        .select("id, current_stock")
        .in("id", ingredientIds);

      const allHaveStock = (ingredients || []).every(
        (i) => Number(i.current_stock) > 0
      );

      if (allHaveStock) {
        productsToEnable.push({ id: product.id, name: product.name });
      }
    }

    if (productsToEnable.length === 0) {
      return { enabled, actionLogged: false };
    }

    // Enable the products
    const idsToEnable = productsToEnable.map((p) => p.id);
    const { error: updateErr } = await supabase
      .from("products")
      .update({ is_available: true })
      .in("id", idsToEnable)
      .eq("outlet_id", outletId);

    if (updateErr) {
      console.error("[TRIGGER] Failed to enable products:", updateErr);
      return { enabled, actionLogged: false };
    }

    const enabledNames = productsToEnable.map((p) => p.name);
    enabled.push(...enabledNames);

    // Create insight
    await supabase.from("ai_insights").insert({
      outlet_id: outletId,
      insight_type: "stock_prediction",
      title: `${productsToEnable.length} produk diaktifkan kembali!`,
      description: `Stok "${ingredientName}" sudah diisi ulang. Produk berikut telah diaktifkan kembali: ${enabledNames.join(", ")}`,
      severity: "positive",
      data: {
        ingredient_id: ingredientId,
        ingredient_name: ingredientName,
        enabled_products: productsToEnable,
        auto_action: true,
      },
      status: "active",
      expires_at: new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString(),
    });

    // Log action
    await supabase.from("ai_action_logs").insert({
      outlet_id: outletId,
      feature_key: "auto_enable_product",
      trust_level: trustLevel,
      action_type: "auto_executed",
      action_description: `Mengaktifkan kembali ${productsToEnable.length} produk setelah "${ingredientName}" di-restock: ${enabledNames.join(", ")}`,
      action_data: {
        ingredient_id: ingredientId,
        ingredient_name: ingredientName,
        enabled_products: productsToEnable,
      },
      source: "trigger",
      undo_deadline: new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString(),
    });
    actionLogged = true;

    return { enabled, actionLogged };
  } catch (err) {
    console.error("[TRIGGER] autoEnableProducts error:", err);
    return { enabled, actionLogged };
  }
}

// --------------- Helper: Check Stock Thresholds ---------------
// After an order is completed, check if any ingredients crossed thresholds
async function checkStockThresholds(
  supabase: SupabaseClient,
  outletId: string,
  orderId: string
): Promise<{ alerts: string[]; insightsCreated: number }> {
  const alerts: string[] = [];
  let insightsCreated = 0;

  try {
    // Get order items to know which products were in the order
    const { data: orderItems, error: itemErr } = await supabase
      .from("order_items")
      .select("product_id, product_name, quantity")
      .eq("order_id", orderId)
      .neq("status", "cancelled");

    if (itemErr || !orderItems || orderItems.length === 0) {
      return { alerts, insightsCreated };
    }

    const productIds = orderItems.map((oi) => oi.product_id);

    // Get all ingredients used by these products
    const { data: recipes, error: recipeErr } = await supabase
      .from("recipes")
      .select("product_id, ingredient_id, quantity")
      .in("product_id", productIds);

    if (recipeErr || !recipes || recipes.length === 0) {
      return { alerts, insightsCreated };
    }

    const ingredientIds = [...new Set(recipes.map((r) => r.ingredient_id))];

    // Get current stock levels for these ingredients
    const { data: ingredients, error: ingrErr } = await supabase
      .from("ingredients")
      .select("id, name, unit, current_stock, min_stock")
      .in("id", ingredientIds)
      .eq("outlet_id", outletId);

    if (ingrErr || !ingredients) {
      return { alerts, insightsCreated };
    }

    // Check each ingredient for threshold crossings
    const criticalItems: Array<{ id: string; name: string; stock: number; min: number; unit: string }> = [];
    const outOfStockItems: Array<{ id: string; name: string; unit: string }> = [];

    for (const ing of ingredients) {
      const currentStock = Number(ing.current_stock);
      const minStock = Number(ing.min_stock);

      if (currentStock <= 0) {
        outOfStockItems.push({ id: ing.id, name: ing.name, unit: ing.unit });
        alerts.push(`${ing.name}: HABIS`);
      } else if (currentStock <= minStock) {
        criticalItems.push({
          id: ing.id,
          name: ing.name,
          stock: currentStock,
          min: minStock,
          unit: ing.unit,
        });
        alerts.push(`${ing.name}: ${currentStock} ${ing.unit} (min: ${minStock})`);
      }
    }

    // Create insights for critical/out-of-stock items
    if (outOfStockItems.length > 0) {
      const names = outOfStockItems.map((i) => i.name).join(", ");
      await supabase.from("ai_insights").insert({
        outlet_id: outletId,
        insight_type: "stock_prediction",
        title: `${outOfStockItems.length} bahan baku habis setelah order!`,
        description: `Setelah order selesai, bahan baku berikut menjadi habis: ${names}. Segera restock dan pertimbangkan menonaktifkan produk terkait.`,
        severity: "critical",
        data: {
          order_id: orderId,
          out_of_stock_items: outOfStockItems,
        },
        suggested_action: {
          type: "restock_and_disable",
          description: "Restock segera dan nonaktifkan produk jika perlu",
        },
        status: "active",
        expires_at: new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString(),
      });
      insightsCreated++;

      // Trigger auto-disable for out-of-stock ingredients
      for (const item of outOfStockItems) {
        await autoDisableProducts(supabase, outletId, item.id, item.name);
      }
    }

    if (criticalItems.length > 0) {
      const itemDetails = criticalItems
        .map((i) => `${i.name} (${i.stock} ${i.unit}, min: ${i.min})`)
        .join(", ");

      await supabase.from("ai_insights").insert({
        outlet_id: outletId,
        insight_type: "stock_prediction",
        title: `${criticalItems.length} bahan baku di bawah stok minimum`,
        description: `Stok menipis setelah order: ${itemDetails}`,
        severity: "warning",
        data: {
          order_id: orderId,
          critical_items: criticalItems,
        },
        suggested_action: {
          type: "create_purchase_order",
          description: "Buat PO restock untuk bahan baku yang menipis",
          items: criticalItems.map((i) => ({
            ingredient_id: i.id,
            name: i.name,
          })),
        },
        status: "active",
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      });
      insightsCreated++;
    }

    return { alerts, insightsCreated };
  } catch (err) {
    console.error("[TRIGGER] checkStockThresholds error:", err);
    return { alerts, insightsCreated };
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

    const payload: TriggerPayload = await req.json();
    const { type, table, record, old_record } = payload;

    console.log(`[AI TRIGGER] ${type} on ${table}`, JSON.stringify(record?.id || "unknown"));

    if (!type || !table || !record) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: type, table, record" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const result: TriggerResult = {
      trigger_type: `${type}_${table}`,
      actions_taken: [],
      insights_created: 0,
      details: "",
    };

    // ===================================================================
    // TRIGGER: Ingredient stock changes
    // ===================================================================
    if (table === "ingredients" && type === "UPDATE") {
      const outletId = record.outlet_id as string;
      const ingredientId = record.id as string;
      const ingredientName = record.name as string;
      const newStock = Number(record.current_stock);
      const oldStock = old_record ? Number(old_record.current_stock) : null;

      // Case 1: Stock reached 0 (was > 0, now <= 0)
      if (oldStock !== null && oldStock > 0 && newStock <= 0) {
        console.log(`[AI TRIGGER] Ingredient "${ingredientName}" reached 0 stock`);

        const { disabled, actionLogged } = await autoDisableProducts(
          supabase,
          outletId,
          ingredientId,
          ingredientName
        );

        if (disabled.length > 0) {
          result.actions_taken.push(`Disabled ${disabled.length} products: ${disabled.join(", ")}`);
        }
        if (actionLogged) {
          result.insights_created++;
        }
        result.details = `Ingredient "${ingredientName}" stock reached 0. ${disabled.length} products auto-disabled.`;
      }

      // Case 2: Stock replenished (was 0 or less, now > 0)
      if (oldStock !== null && oldStock <= 0 && newStock > 0) {
        console.log(`[AI TRIGGER] Ingredient "${ingredientName}" replenished to ${newStock}`);

        const { enabled, actionLogged } = await autoEnableProducts(
          supabase,
          outletId,
          ingredientId,
          ingredientName
        );

        if (enabled.length > 0) {
          result.actions_taken.push(`Enabled ${enabled.length} products: ${enabled.join(", ")}`);
        }
        if (actionLogged) {
          result.insights_created++;
        }
        result.details = `Ingredient "${ingredientName}" replenished. ${enabled.length} products auto-enabled.`;
      }

      // Case 3: Stock dropped below min_stock threshold
      if (
        oldStock !== null &&
        newStock > 0 &&
        newStock <= Number(record.min_stock) &&
        oldStock > Number(record.min_stock)
      ) {
        console.log(`[AI TRIGGER] Ingredient "${ingredientName}" below min stock`);

        await supabase.from("ai_insights").insert({
          outlet_id: outletId,
          insight_type: "stock_prediction",
          title: `Stok "${ingredientName}" di bawah minimum`,
          description: `Stok ${ingredientName} sisa ${newStock} ${record.unit} (minimum: ${record.min_stock} ${record.unit}). Pertimbangkan untuk restock.`,
          severity: "warning",
          data: {
            ingredient_id: ingredientId,
            ingredient_name: ingredientName,
            current_stock: newStock,
            min_stock: record.min_stock,
            unit: record.unit,
          },
          suggested_action: {
            type: "create_purchase_order",
            description: `Restock ${ingredientName}`,
          },
          status: "active",
          expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
        });

        result.insights_created++;
        result.details = `Ingredient "${ingredientName}" below min stock (${newStock}/${record.min_stock} ${record.unit})`;
      }
    }

    // ===================================================================
    // TRIGGER: Order completed
    // ===================================================================
    if (table === "orders" && type === "UPDATE") {
      const newStatus = record.status as string;
      const oldStatus = old_record?.status as string | undefined;

      if (newStatus === "completed" && oldStatus !== "completed") {
        const outletId = record.outlet_id as string;
        const orderId = record.id as string;
        const orderNumber = record.order_number as string;

        console.log(`[AI TRIGGER] Order ${orderNumber} completed. Checking stock thresholds...`);

        const { alerts, insightsCreated } = await checkStockThresholds(
          supabase,
          outletId,
          orderId
        );

        result.insights_created += insightsCreated;

        if (alerts.length > 0) {
          result.actions_taken.push(`Stock alerts after order ${orderNumber}: ${alerts.join("; ")}`);
          result.details = `Order ${orderNumber} completed. ${alerts.length} stock alerts triggered.`;
        } else {
          result.details = `Order ${orderNumber} completed. All stock levels OK.`;
        }
      }
    }

    // ===================================================================
    // TRIGGER: Stock movement created (alternative trigger for stock changes)
    // ===================================================================
    if (table === "stock_movements" && type === "INSERT") {
      const outletId = record.outlet_id as string;
      const ingredientId = record.ingredient_id as string;
      const movementType = record.movement_type as string;

      // For stock_in / purchase_order movements, check if ingredient was at 0
      if (movementType === "stock_in" || movementType === "purchase_order") {
        const { data: ingredient } = await supabase
          .from("ingredients")
          .select("id, name, current_stock")
          .eq("id", ingredientId)
          .single();

        if (ingredient) {
          const quantity = Number(record.quantity);
          // If the stock was just replenished (current stock equals or is close to the quantity just added)
          // This means it was at or near 0 before
          const currentStock = Number(ingredient.current_stock);
          if (currentStock > 0 && currentStock <= quantity * 1.1) {
            // Likely just replenished from 0
            console.log(`[AI TRIGGER] Stock replenished via ${movementType} for ${ingredient.name}`);

            const { enabled } = await autoEnableProducts(
              supabase,
              outletId,
              ingredientId,
              ingredient.name
            );

            if (enabled.length > 0) {
              result.actions_taken.push(`Re-enabled ${enabled.length} products after restock: ${enabled.join(", ")}`);
            }
            result.details = `Stock movement (${movementType}) for ${ingredient.name}. ${enabled.length} products re-enabled.`;
          }
        }
      }
    }

    // If no specific trigger matched
    if (!result.details) {
      result.details = `Event ${type} on ${table} processed. No action needed.`;
    }

    console.log(`[AI TRIGGER] Result:`, JSON.stringify(result));

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[AI TRIGGER] Error:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
