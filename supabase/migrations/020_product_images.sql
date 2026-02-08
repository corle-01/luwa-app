-- ============================================================
-- 020: Product Images - Multi-image support per product
-- ============================================================

-- Create product_images table
CREATE TABLE IF NOT EXISTS product_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast lookup by product
CREATE INDEX IF NOT EXISTS idx_product_images_product_id ON product_images(product_id);
CREATE INDEX IF NOT EXISTS idx_product_images_sort_order ON product_images(product_id, sort_order);

-- RLS policies for anon access (POS web app uses anon key)
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_select_product_images" ON product_images
  FOR SELECT TO anon USING (true);

CREATE POLICY "anon_insert_product_images" ON product_images
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "anon_update_product_images" ON product_images
  FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "anon_delete_product_images" ON product_images
  FOR DELETE TO anon USING (true);

-- Create storage bucket for product images (via SQL)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: allow anon to upload/read/delete from product-images bucket
CREATE POLICY "anon_select_product_images_storage" ON storage.objects
  FOR SELECT TO anon USING (bucket_id = 'product-images');

CREATE POLICY "anon_insert_product_images_storage" ON storage.objects
  FOR INSERT TO anon WITH CHECK (bucket_id = 'product-images');

CREATE POLICY "anon_update_product_images_storage" ON storage.objects
  FOR UPDATE TO anon USING (bucket_id = 'product-images') WITH CHECK (bucket_id = 'product-images');

CREATE POLICY "anon_delete_product_images_storage" ON storage.objects
  FOR DELETE TO anon USING (bucket_id = 'product-images');
