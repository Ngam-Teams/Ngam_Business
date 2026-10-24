-- =========================================================================================
-- NGAM ECOSYSTEM - EXTEND VOUCHERS TABLE FOR REWARDS & ADVANCED PROMOTIONS
-- =========================================================================================

-- 1. Buka kekangan CHECK discount_type untuk menyokong ganjaran percuma & promosi lanjutan
ALTER TABLE public.vouchers DROP CONSTRAINT IF EXISTS vouchers_discount_type_check;
ALTER TABLE public.vouchers ADD CONSTRAINT vouchers_discount_type_check 
  CHECK (discount_type IN ('percentage', 'fixed_amount', 'free_item', 'buy_x_get_y', 'points_multiplier', 'free_shipping'));

-- 2. Tambah lajur pilihan untuk nama item/servis ganjaran
ALTER TABLE public.vouchers ADD COLUMN IF NOT EXISTS reward_item_name TEXT;
ALTER TABLE public.vouchers ADD COLUMN IF NOT EXISTS reward_item_id UUID;
ALTER TABLE public.vouchers ADD COLUMN IF NOT EXISTS points_multiplier NUMERIC(5, 2) DEFAULT 1.0;

-- 3. Pastikan kebenaran PostgREST RLS sentiasa aktif
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vouchers TO authenticated;
GRANT SELECT ON public.vouchers TO anon;
GRANT ALL ON public.vouchers TO service_role;

-- Makluman:
-- Sistem aplikasi Ngam Business telah dilengkapi mekanisma sandaran automatik (embedded tags [Reward: xxx] dalam description)
-- jadi baucar ganjaran tetap berfungsi 100% walaupun sebelum skrip SQL ini dijalankan di Supabase.
