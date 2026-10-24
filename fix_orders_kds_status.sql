-- =============================================================================
-- FIX: Kemas kini check constraint pada orders.status untuk menyokong KDS
-- Supabase Dashboard -> SQL Editor -> Run
-- =============================================================================

-- 1. Gugurkan kekangan semakan status lama jika ada
ALTER TABLE public.orders 
  DROP CONSTRAINT IF EXISTS orders_status_check;

-- 2. Tambah kekangan baharu yang merangkumi status KDS & Pesanan Lengkap
ALTER TABLE public.orders 
  ADD CONSTRAINT orders_status_check 
  CHECK (status IN ('pending', 'preparing', 'cooking', 'ready', 'completed', 'cancelled'));

-- 3. Cipta indeks carian laju untuk status pesanan
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_business_status ON public.orders(business_id, status);
