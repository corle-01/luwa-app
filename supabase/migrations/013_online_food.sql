-- ============================================================
-- Migration 013: Online Food Integration
-- Platform configs + online orders tracking
-- ============================================================

-- Platform configurations (GoFood, GrabFood, ShopeeFood, etc.)
CREATE TABLE IF NOT EXISTS platform_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  platform TEXT NOT NULL, -- 'gofood', 'grabfood', 'shopeefood'
  is_enabled BOOLEAN DEFAULT false,
  store_id TEXT, -- Platform-specific store/merchant ID
  api_key TEXT, -- Platform API key (encrypted in production)
  webhook_url TEXT, -- Webhook endpoint for receiving orders
  auto_accept BOOLEAN DEFAULT false, -- Auto-accept incoming orders
  settings JSONB DEFAULT '{}', -- Platform-specific settings
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(outlet_id, platform)
);

-- Online orders from food platforms
CREATE TABLE IF NOT EXISTS online_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES outlets(id),
  order_id UUID REFERENCES orders(id), -- Link to internal order (after accepted)
  platform TEXT NOT NULL, -- 'gofood', 'grabfood', 'shopeefood'
  platform_order_id TEXT NOT NULL, -- Order ID from the platform
  platform_order_number TEXT, -- Display order number from platform
  status TEXT DEFAULT 'incoming' CHECK (status IN (
    'incoming', 'accepted', 'preparing', 'ready', 'picked_up', 'delivered', 'cancelled', 'rejected'
  )),
  customer_name TEXT,
  customer_phone TEXT,
  customer_address TEXT,
  delivery_fee DECIMAL(12,2) DEFAULT 0,
  platform_fee DECIMAL(12,2) DEFAULT 0,
  subtotal DECIMAL(12,2) DEFAULT 0,
  total DECIMAL(12,2) DEFAULT 0,
  items JSONB NOT NULL DEFAULT '[]', -- Raw items from platform
  driver_name TEXT,
  driver_phone TEXT,
  notes TEXT,
  raw_data JSONB DEFAULT '{}', -- Full raw payload from platform
  accepted_at TIMESTAMPTZ,
  prepared_at TIMESTAMPTZ,
  picked_up_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_online_orders_outlet ON online_orders(outlet_id);
CREATE INDEX IF NOT EXISTS idx_online_orders_platform ON online_orders(platform);
CREATE INDEX IF NOT EXISTS idx_online_orders_status ON online_orders(status);
CREATE INDEX IF NOT EXISTS idx_online_orders_created ON online_orders(created_at);
CREATE INDEX IF NOT EXISTS idx_platform_configs_outlet ON platform_configs(outlet_id);

-- RLS
ALTER TABLE platform_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE online_orders ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_platform_configs') THEN
    CREATE POLICY anon_select_platform_configs ON platform_configs FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_platform_configs') THEN
    CREATE POLICY anon_insert_platform_configs ON platform_configs FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_platform_configs') THEN
    CREATE POLICY anon_update_platform_configs ON platform_configs FOR UPDATE TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_delete_platform_configs') THEN
    CREATE POLICY anon_delete_platform_configs ON platform_configs FOR DELETE TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_select_online_orders') THEN
    CREATE POLICY anon_select_online_orders ON online_orders FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_insert_online_orders') THEN
    CREATE POLICY anon_insert_online_orders ON online_orders FOR INSERT TO anon WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'anon_update_online_orders') THEN
    CREATE POLICY anon_update_online_orders ON online_orders FOR UPDATE TO anon USING (true);
  END IF;
END $$;

-- Seed default platform configs
INSERT INTO platform_configs (outlet_id, platform, is_enabled, settings)
SELECT 'a0000000-0000-0000-0000-000000000001', 'gofood', false, '{"commission_rate": 20}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM platform_configs WHERE outlet_id = 'a0000000-0000-0000-0000-000000000001' AND platform = 'gofood');

INSERT INTO platform_configs (outlet_id, platform, is_enabled, settings)
SELECT 'a0000000-0000-0000-0000-000000000001', 'grabfood', false, '{"commission_rate": 25}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM platform_configs WHERE outlet_id = 'a0000000-0000-0000-0000-000000000001' AND platform = 'grabfood');

INSERT INTO platform_configs (outlet_id, platform, is_enabled, settings)
SELECT 'a0000000-0000-0000-0000-000000000001', 'shopeefood', false, '{"commission_rate": 15}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM platform_configs WHERE outlet_id = 'a0000000-0000-0000-0000-000000000001' AND platform = 'shopeefood');
