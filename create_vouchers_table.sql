-- =========================================================================================
-- NGAM ECOSYSTEM - E-COMMERCE VOUCHER & PROMOTIONS SYSTEM
-- Modul: Sistem Baucar Promosi Standard E-Commerce (Shopee/Lazada/Shopify Grade)
-- Ciri-ciri:
-- 1. Diskaun Peratus (%) atau Nilai Tetap (RM)
-- 2. Had Maksimum Diskaun (Max Discount Capping cth: 10% capped at RM15)
-- 3. Syarat Belanja Minimum (Min Spend)
-- 4. Had Kuota Keseluruhan (Total Usage Limit)
-- 5. Had Penebusan Setiap Pelanggan (Usage Limit Per User)
-- 6. Tempoh Sah Lengkap (Tarikh & Masa Mula serta Tarikh Luput)
-- 7. Kelayakan Sasaran Pelanggan (Semua, Pelanggan Baru, Ahli VIP)
-- 8. Pengesanan Penggunaan & Rekod Audit (Voucher Usages Trail)
-- =========================================================================================

-- 1. Jadual Utama Baucar (vouchers)
CREATE TABLE IF NOT EXISTS public.vouchers (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id           UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  code                  TEXT NOT NULL,
  title                 TEXT NOT NULL,
  description           TEXT,
  discount_type         TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed_amount')),
  discount_value        NUMERIC(10, 2) NOT NULL CHECK (discount_value > 0),
  max_discount_amount   NUMERIC(10, 2), -- Had siling diskaun untuk jenis peratus
  min_spend             NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (min_spend >= 0),
  total_usage_limit     INTEGER, -- NULL = kuota tanpa had
  usage_limit_per_user  INTEGER NOT NULL DEFAULT 1 CHECK (usage_limit_per_user >= 1),
  times_used            INTEGER NOT NULL DEFAULT 0 CHECK (times_used >= 0),
  start_date            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_date              TIMESTAMPTZ, -- NULL = tiada tarikh luput
  applicable_scope      TEXT NOT NULL DEFAULT 'all' CHECK (applicable_scope IN ('all', 'category', 'specific_products')),
  applicable_ids        JSONB DEFAULT '[]'::jsonb,
  customer_eligibility  TEXT NOT NULL DEFAULT 'all' CHECK (customer_eligibility IN ('all', 'new_customers', 'members_only')),
  is_active             BOOLEAN NOT NULL DEFAULT true,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_business_voucher_code UNIQUE (business_id, code)
);

-- 2. Jadual Rekod Penggunaan Baucar (voucher_usages)
CREATE TABLE IF NOT EXISTS public.voucher_usages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voucher_id      UUID NOT NULL REFERENCES public.vouchers(id) ON DELETE CASCADE,
  business_id     UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  order_id        UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  discount_amount NUMERIC(10, 2) NOT NULL CHECK (discount_amount >= 0),
  order_subtotal  NUMERIC(10, 2) NOT NULL CHECK (order_subtotal >= 0),
  customer_phone  TEXT,
  used_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index untuk carian pantas & prestasi tinggi
CREATE INDEX IF NOT EXISTS idx_vouchers_business_id ON public.vouchers(business_id);
CREATE INDEX IF NOT EXISTS idx_vouchers_code ON public.vouchers(code);
CREATE INDEX IF NOT EXISTS idx_vouchers_is_active ON public.vouchers(is_active);
CREATE INDEX IF NOT EXISTS idx_vouchers_dates ON public.vouchers(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_voucher_usages_voucher_id ON public.voucher_usages(voucher_id);
CREATE INDEX IF NOT EXISTS idx_voucher_usages_user_id ON public.voucher_usages(user_id);
CREATE INDEX IF NOT EXISTS idx_voucher_usages_business_id ON public.voucher_usages(business_id);

-- 3. Row Level Security (RLS)
ALTER TABLE public.vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voucher_usages ENABLE ROW LEVEL SECURITY;

-- Polisi SELECT Vouchers:
DROP POLICY IF EXISTS "Vouchers select policy" ON public.vouchers;
CREATE POLICY "Vouchers select policy"
  ON public.vouchers FOR SELECT
  USING (
    (is_active = true AND NOW() >= start_date AND (end_date IS NULL OR NOW() <= end_date))
    OR (
      auth.uid() IS NOT NULL AND (
        EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = vouchers.business_id AND b.owner_user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = vouchers.business_id AND tm.user_id = auth.uid() AND tm.status = 'active') OR
        EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
      )
    )
  );

-- Polisi INSERT Vouchers:
DROP POLICY IF EXISTS "Vouchers insert policy" ON public.vouchers;
CREATE POLICY "Vouchers insert policy"
  ON public.vouchers FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = vouchers.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = vouchers.business_id AND tm.user_id = auth.uid() AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- Polisi UPDATE Vouchers:
DROP POLICY IF EXISTS "Vouchers update policy" ON public.vouchers;
CREATE POLICY "Vouchers update policy"
  ON public.vouchers FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = vouchers.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = vouchers.business_id AND tm.user_id = auth.uid() AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = vouchers.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = vouchers.business_id AND tm.user_id = auth.uid() AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- Polisi DELETE Vouchers:
DROP POLICY IF EXISTS "Vouchers delete policy" ON public.vouchers;
CREATE POLICY "Vouchers delete policy"
  ON public.vouchers FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = vouchers.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = vouchers.business_id AND tm.user_id = auth.uid() AND tm.role IN ('tenant_admin', 'manager') AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- Polisi Voucher Usages:
DROP POLICY IF EXISTS "Voucher usages select policy" ON public.voucher_usages;
CREATE POLICY "Voucher usages select policy"
  ON public.voucher_usages FOR SELECT
  USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = voucher_usages.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = voucher_usages.business_id AND tm.user_id = auth.uid() AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

DROP POLICY IF EXISTS "Voucher usages insert policy" ON public.voucher_usages;
CREATE POLICY "Voucher usages insert policy"
  ON public.voucher_usages FOR INSERT
  WITH CHECK (true);

-- 4. Hak Akses (Table Grants) - WAJIB untuk PostgREST Supabase
-- Menghalang ralat PostgrestException 42501 (permission denied for table vouchers)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vouchers TO authenticated;
GRANT SELECT ON public.vouchers TO anon;
GRANT ALL ON public.vouchers TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.voucher_usages TO authenticated;
GRANT SELECT, INSERT ON public.voucher_usages TO anon;
GRANT ALL ON public.voucher_usages TO service_role;

GRANT SELECT ON public.businesses TO anon, authenticated;
GRANT SELECT ON public.team_members TO authenticated;
GRANT SELECT ON public.user_roles TO authenticated;

-- 5. Fungsi Validasi & Pengiraan Baucar Standard E-Commerce (RPC)
CREATE OR REPLACE FUNCTION public.validate_voucher_discount(
  p_business_id   UUID,
  p_code          TEXT,
  p_subtotal      NUMERIC,
  p_user_id       UUID DEFAULT NULL,
  p_customer_phone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_voucher RECORD;
  v_user_uses INTEGER := 0;
  v_discount NUMERIC := 0;
  v_raw_discount NUMERIC := 0;
BEGIN
  -- Cari baucar berdasarkan business_id dan kod (case-insensitive)
  SELECT *
  INTO v_voucher
  FROM public.vouchers
  WHERE business_id = p_business_id
    AND UPPER(code) = UPPER(trim(p_code))
  LIMIT 1;

  IF v_voucher.id IS NULL THEN
    RETURN jsonb_build_object(
      'valid', false,
      'message', 'Kod baucar tidak sah atau tidak wujud.'
    );
  END IF;

  -- 1. Semakan Status Aktif
  IF NOT v_voucher.is_active THEN
    RETURN jsonb_build_object(
      'valid', false,
      'message', 'Baucar ini telah dinyahaktifkan.'
    );
  END IF;

  -- 2. Semakan Tarikh Mula
  IF NOW() < v_voucher.start_date THEN
    RETURN jsonb_build_object(
      'valid', false,
      'message', 'Baucar ini belum bermula lagi.'
    );
  END IF;

  -- 3. Semakan Tarikh Luput
  IF v_voucher.end_date IS NOT NULL AND NOW() > v_voucher.end_date THEN
    RETURN jsonb_build_object(
      'valid', false,
      'message', 'Baucar ini telah tamat tempoh.'
    );
  END IF;

  -- 4. Semakan Kuota Keseluruhan
  IF v_voucher.total_usage_limit IS NOT NULL AND v_voucher.times_used >= v_voucher.total_usage_limit THEN
    RETURN jsonb_build_object(
      'valid', false,
      'message', 'Semua kuota baucar ini telah habis ditebus.'
    );
  END IF;

  -- 5. Semakan Belanja Minimum
  IF p_subtotal < v_voucher.min_spend THEN
    RETURN jsonb_build_object(
      'valid', false,
      'message', format('Belanja minimum RM %s diperlukan untuk menebus baucar ini.', to_char(v_voucher.min_spend, 'FM999,990.00'))
    );
  END IF;

  -- 6. Semakan Had Guna Setiap Pelanggan
  IF p_user_id IS NOT NULL OR p_customer_phone IS NOT NULL THEN
    SELECT COUNT(*)
    INTO v_user_uses
    FROM public.voucher_usages
    WHERE voucher_id = v_voucher.id
      AND (
        (p_user_id IS NOT NULL AND user_id = p_user_id) OR
        (p_customer_phone IS NOT NULL AND customer_phone = p_customer_phone)
      );

    IF v_user_uses >= v_voucher.usage_limit_per_user THEN
      RETURN jsonb_build_object(
        'valid', false,
        'message', format('Anda telah mencapai had penebusan (%s kali) untuk baucar ini.', v_voucher.usage_limit_per_user)
      );
    END IF;
  END IF;

  -- 7. Pengiraan Diskaun E-Commerce
  IF v_voucher.discount_type = 'percentage' THEN
    v_raw_discount := (p_subtotal * (v_voucher.discount_value / 100.0));
    IF v_voucher.max_discount_amount IS NOT NULL AND v_voucher.max_discount_amount > 0 THEN
      v_discount := LEAST(v_raw_discount, v_voucher.max_discount_amount);
    ELSE
      v_discount := v_raw_discount;
    END IF;
  ELSIF v_voucher.discount_type = 'fixed_amount' THEN
    v_discount := LEAST(v_voucher.discount_value, p_subtotal);
  END IF;

  -- Pastikan diskaun tidak melebihi subtotal
  v_discount := LEAST(v_discount, p_subtotal);

  RETURN jsonb_build_object(
    'valid', true,
    'voucher_id', v_voucher.id,
    'code', v_voucher.code,
    'title', v_voucher.title,
    'discount_type', v_voucher.discount_type,
    'discount_value', v_voucher.discount_value,
    'max_discount_amount', v_voucher.max_discount_amount,
    'discount_amount', ROUND(v_discount, 2),
    'final_total', ROUND(p_subtotal - v_discount, 2),
    'message', format('Baucar %s berjaya ditebus! Jimat RM %s', v_voucher.code, to_char(v_discount, 'FM999,990.00'))
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.validate_voucher_discount(UUID, TEXT, NUMERIC, UUID, TEXT) TO anon, authenticated;
