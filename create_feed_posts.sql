-- =========================================================================================
-- NGAM ECOSYSTEM - FEED POSTS TABLE & RLS POLICIES (FASA 1: BASE ENGINE)
-- Digunakan oleh:
-- 1. Ngam Business (Pusat Cipta, Sunting, Pin & Analitik Post Peniaga)
-- 2. Ngam Consumer App (CustomerFeedScreen - Live TikTok / Reels feed pengguna)
-- =========================================================================================

-- 1. Cipta Jadual feed_posts jika belum wujud
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

-- 2. Index untuk carian pantas & penapisan prestasi tinggi
CREATE INDEX IF NOT EXISTS idx_feed_posts_business_id ON public.feed_posts(business_id);
CREATE INDEX IF NOT EXISTS idx_feed_posts_status ON public.feed_posts(status);
CREATE INDEX IF NOT EXISTS idx_feed_posts_created_at ON public.feed_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_posts_category ON public.feed_posts(category);
CREATE INDEX IF NOT EXISTS idx_feed_posts_pinned ON public.feed_posts(is_pinned);

-- 3. Aktifkan Row Level Security (RLS)
ALTER TABLE public.feed_posts ENABLE ROW LEVEL SECURITY;

-- 4. Polisi RLS (Row Level Security)
-- A. Polisi BACA (SELECT):
-- Awam & Pelanggan (anon & authenticated) boleh membaca pos bertaraf 'published'
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

-- B. Polisi CIPTA (INSERT):
-- Hanya pemilik kedai atau staf aktif
DROP POLICY IF EXISTS "Feed posts insert policy" ON public.feed_posts;
CREATE POLICY "Feed posts insert policy"
  ON public.feed_posts FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = feed_posts.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = feed_posts.business_id AND tm.user_id = auth.uid() AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- C. Polisi KEMASKINI (UPDATE):
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

-- D. Polisi PADAM (DELETE):
DROP POLICY IF EXISTS "Feed posts delete policy" ON public.feed_posts;
CREATE POLICY "Feed posts delete policy"
  ON public.feed_posts FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = feed_posts.business_id AND b.owner_user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = feed_posts.business_id AND tm.user_id = auth.uid() AND tm.role IN ('tenant_admin', 'manager') AND tm.status = 'active') OR
    EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.role = 'super_admin')
  );

-- 5. Pastikan Kolum Sokongan Wujud pada Jadual businesses jika belum ada
ALTER TABLE public.businesses ADD COLUMN IF NOT EXISTS business_handle TEXT;
ALTER TABLE public.businesses ADD COLUMN IF NOT EXISTS business_logo_url TEXT;

-- Kemaskini business_handle automatik untuk kedai sedia ada jika masih kosong
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'businesses' AND column_name = 'business_handle') THEN
    UPDATE public.businesses
    SET business_handle = LOWER(REGEXP_REPLACE(business_name, '[^a-zA-Z0-9]+', '', 'g'))
    WHERE business_handle IS NULL OR business_handle = '';
  END IF;
END $$;

-- 6. Kebenaran Akses SQL (Permissions)
GRANT SELECT ON public.feed_posts TO anon, authenticated;
GRANT ALL ON public.feed_posts TO authenticated;
GRANT ALL ON public.feed_posts TO service_role;

-- Beri kebenaran SELECT pada jadual businesses untuk pelawat awam & pelanggan suapan
GRANT SELECT ON public.businesses TO anon, authenticated;

-- 7. Fungsi RPC Selamat untuk Kiraan Tontonan & Sukaan (Views & Likes Increment)
CREATE OR REPLACE FUNCTION public.increment_feed_post_views(p_post_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.feed_posts
  SET views_count = views_count + 1
  WHERE id = p_post_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.increment_feed_post_views(UUID) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.toggle_feed_post_like(p_post_id UUID, p_increment BOOLEAN)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_increment THEN
    UPDATE public.feed_posts
    SET likes_count = likes_count + 1
    WHERE id = p_post_id;
  ELSE
    UPDATE public.feed_posts
    SET likes_count = GREATEST(0, likes_count - 1)
    WHERE id = p_post_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_feed_post_like(UUID, BOOLEAN) TO anon, authenticated;

-- 8. Masukkan Sampel Pos Permulaan secara Automatik jika ada kedai
DO $$
DECLARE
  v_biz_id UUID;
BEGIN
  SELECT id INTO v_biz_id FROM public.businesses LIMIT 1;
  
  IF v_biz_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.feed_posts WHERE business_id = v_biz_id) THEN
    INSERT INTO public.feed_posts (
      business_id, title, caption, media_url, media_type, category, service_tag, cta_type, cta_text, status, is_pinned, likes_count, comments_count, views_count
    ) VALUES 
    (
      v_biz_id,
      'Low Taper Fade + Beard Sculpting 🔥',
      'Hasil sentuhan kemas petang ini. Slot walk-in & nombor giliran dibuka sekarang! #barber #ngam #taperfade',
      'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=800',
      'image',
      'barber',
      '✂️ Potong + Cuci • RM35 · Buka Hingga 10:00 PM',
      'queue',
      '⚡ AMBIL GILIRAN (1 MENUNGGU)',
      'published',
      true,
      142,
      19,
      1280
    ),
    (
      v_biz_id,
      'Cermin Kereta Bersinar Bak Kristal ✨',
      'Pakej Nano Wax Coating + Interior Steam Wash promosi khas pertengahan bulan. Hilangkan watermark! #detailing #carwash',
      'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?q=80&w=800',
      'image',
      'carwash',
      '🚗 Nano Coating • RM45 · 3 Bay Aktif',
      'queue',
      '🚗 MASUK TERUS (0 MENUNGGU)',
      'published',
      false,
      89,
      8,
      940
    ),
    (
      v_biz_id,
      'Iced Salted Caramel Butter Pecan Latte ☕',
      'Port santai lepak sambil nikmati hidangan panas. Ada plug & WiFi laju! #ngamcafe #kopiroti',
      'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?q=80&w=800',
      'image',
      'cafe',
      '☕ Menu Baru Musim Ini • RM14 · Meja Santai',
      'menu',
      '☕ PESAN QR / TEMPAH MEJA',
      'published',
      false,
      234,
      42,
      2100
    );
  END IF;
END $$;
