-- =========================================================================================
-- NGAM ECOSYSTEM - FEED POSTS TABLE & RLS POLICIES
-- Modul: Ngam Feed & Post Studio
-- Digunakan oleh:
-- 1. Ngam Business (Pusat Cipta, Sunting, Pin & Analitik Post Peniaga)
-- 2. Ngam Consumer App (CustomerFeedScreen - TikTok / Reels gaya imersif penuh)
-- =========================================================================================

CREATE TABLE IF NOT EXISTS public.feed_posts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  caption         TEXT,
  media_url       TEXT NOT NULL,
  media_type      TEXT NOT NULL DEFAULT 'image' CHECK (media_type IN ('image', 'video')),
  category        TEXT, -- cth: 'barber', 'carwash', 'cafe', 'workshop', 'retail', 'services'
  service_tag     TEXT, -- cth: '✂️ Potong + Cuci • RM35 · Buka Hingga 10:00 PM'
  cta_type        TEXT NOT NULL DEFAULT 'queue' CHECK (cta_type IN ('queue', 'booking', 'menu', 'whatsapp', 'general')),
  cta_text        TEXT NOT NULL DEFAULT '⚡ AMBIL GILIRAN',
  status          TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('published', 'draft', 'archived')),
  is_pinned       BOOLEAN NOT NULL DEFAULT false,
  likes_count     INTEGER NOT NULL DEFAULT 0,
  comments_count  INTEGER NOT NULL DEFAULT 0,
  shares_count    INTEGER NOT NULL DEFAULT 0,
  views_count     INTEGER NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index untuk carian & penapisan pantas
CREATE INDEX IF NOT EXISTS idx_feed_posts_business_id ON public.feed_posts(business_id);
CREATE INDEX IF NOT EXISTS idx_feed_posts_status ON public.feed_posts(status);
CREATE INDEX IF NOT EXISTS idx_feed_posts_created_at ON public.feed_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_posts_category ON public.feed_posts(category);
CREATE INDEX IF NOT EXISTS idx_feed_posts_pinned ON public.feed_posts(is_pinned);

-- Aktifkan Row Level Security (RLS)
ALTER TABLE public.feed_posts ENABLE ROW LEVEL SECURITY;

-- 1. Polisi BACA (SELECT):
-- Awam / pelanggan boleh lihat semua post 'published'.
-- Peniaga (pemilik & staf) boleh lihat SEMUA post kedai mereka termasuk 'draft' & 'archived'.
DROP POLICY IF EXISTS "Feed posts select policy" ON public.feed_posts;
CREATE POLICY "Feed posts select policy"
  ON public.feed_posts FOR SELECT
  USING (
    status = 'published' OR (
      auth.uid() IS NOT NULL AND (
        EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = feed_posts.business_id AND b.owner_user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = feed_posts.business_id AND tm.user_id = auth.uid() AND tm.status = 'active') OR
        EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
      )
    )
  );

-- 2. Polisi CIPTA (INSERT):
-- Hanya pemilik kedai atau staf aktif kedai tersebut
DROP POLICY IF EXISTS "Feed posts insert policy" ON public.feed_posts;
CREATE POLICY "Feed posts insert policy"
  ON public.feed_posts FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = feed_posts.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = feed_posts.business_id AND tm.user_id = auth.uid() AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- 3. Polisi KEMASKINI (UPDATE):
-- Pemilik kedai atau staf aktif boleh sunting post kedai mereka
DROP POLICY IF EXISTS "Feed posts update policy" ON public.feed_posts;
CREATE POLICY "Feed posts update policy"
  ON public.feed_posts FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = feed_posts.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = feed_posts.business_id AND tm.user_id = auth.uid() AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = feed_posts.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = feed_posts.business_id AND tm.user_id = auth.uid() AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- 4. Polisi PADAM (DELETE):
-- Pemilik kedai, pengurus (manager/tenant_admin), atau super_admin
DROP POLICY IF EXISTS "Feed posts delete policy" ON public.feed_posts;
CREATE POLICY "Feed posts delete policy"
  ON public.feed_posts FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = feed_posts.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = feed_posts.business_id AND tm.user_id = auth.uid() AND tm.role IN ('tenant_admin', 'manager') AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );
