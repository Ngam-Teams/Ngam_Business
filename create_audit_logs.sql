-- =========================================================================================
-- NGAM ECOSYSTEM - AUDIT LOGS & TAMPER-RESISTANT ACTIVITY TRAIL
-- Tarikh: 2026-10-19
-- =========================================================================================

-- 1. Bina jadual audit_logs
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id   UUID REFERENCES public.businesses(id) ON DELETE CASCADE,
  actor_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_name    TEXT NOT NULL DEFAULT 'System',
  actor_email   TEXT,
  actor_role    TEXT NOT NULL DEFAULT 'staff',
  action        TEXT NOT NULL, -- cth: 'VOID_ORDER', 'PRICE_CHANGE', 'CASH_DRAWER_OPEN', 'MFA_ENABLED', 'MFA_DISABLED', 'STAFF_ROLE_CHANGE'
  severity      TEXT NOT NULL DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
  target_type   TEXT, -- cth: 'order', 'product', 'staff', 'settings', 'auth', 'cash_drawer'
  target_id     TEXT,
  description   TEXT NOT NULL,
  metadata      JSONB DEFAULT '{}'::jsonb,
  ip_address    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Indexes untuk carian pantas
CREATE INDEX IF NOT EXISTS idx_audit_logs_business_id ON public.audit_logs(business_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_severity ON public.audit_logs(severity);

-- 3. Aktifkan Row Level Security (RLS)
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 4. Polisi RLS - BACA (SELECT): Pemilik kedai, Pengurus, & Super Admin sahaja
DROP POLICY IF EXISTS "Audit logs select policy" ON public.audit_logs;
CREATE POLICY "Audit logs select policy"
  ON public.audit_logs FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = audit_logs.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = audit_logs.business_id AND tm.user_id = auth.uid() AND tm.role IN ('tenant_admin', 'manager') AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- 5. Polisi RLS - CIPTA (INSERT): Sebarang staf sah boleh merekod log audit
DROP POLICY IF EXISTS "Audit logs insert policy" ON public.audit_logs;
CREATE POLICY "Audit logs insert policy"
  ON public.audit_logs FOR INSERT TO authenticated
  WITH CHECK (
    actor_user_id = auth.uid() AND (
      EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = audit_logs.business_id AND b.owner_user_id = auth.uid()) OR
      EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = audit_logs.business_id AND tm.user_id = auth.uid() AND tm.status = 'active') OR
      EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
    )
  );

-- 6. KESELAMATAN KETAT (IMMUTABILITY):
-- Tiada sebarang polisi UPDATE atau DELETE dibenarkan!
-- Ini menghalang sesiapa (termasuk staf dalaman atau pengurus) daripada mengubah atau memadam sejarah audit (tamper-proof).
