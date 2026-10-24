-- =========================================================================================
-- FIX PERMISSION DENIED (42501) FOR VOUCHERS TABLE
-- Sila 'Run' skrip ini dalam Supabase Dashboard -> SQL Editor
-- =========================================================================================

-- 1. Berikan kebenaran CRUD pada jadual vouchers & voucher_usages
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vouchers TO authenticated;
GRANT SELECT ON public.vouchers TO anon;
GRANT ALL ON public.vouchers TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.voucher_usages TO authenticated;
GRANT SELECT, INSERT ON public.voucher_usages TO anon;
GRANT ALL ON public.voucher_usages TO service_role;

-- 2. Pastikan subquery RLS untuk perniagaan & staf dapat dibaca
GRANT SELECT ON public.businesses TO anon, authenticated;
GRANT SELECT ON public.team_members TO authenticated;
GRANT SELECT ON public.user_roles TO authenticated;

-- 3. Kebenaran pelaksanaan fungsi RPC validate_voucher_discount
GRANT EXECUTE ON FUNCTION public.validate_voucher_discount(UUID, TEXT, NUMERIC, UUID, TEXT) TO anon, authenticated;
