-- =========================================================================================
-- NGAM ECOSYSTEM - FEED COMMENTS TABLE & RLS POLICIES
-- Digunakan oleh:
-- 1. Ngam (CustomerFeedScreen - Komen Live gaya TikTok)
-- 2. Ngam Business (FeedManagementPage - Paparan dan balasan komen pelanggan)
-- =========================================================================================

-- 1. Cipta Jadual feed_comments jika belum wujud
CREATE TABLE IF NOT EXISTS public.feed_comments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id         UUID NOT NULL REFERENCES public.feed_posts(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user_name       TEXT NOT NULL DEFAULT 'Pelanggan Ngam',
  user_avatar     TEXT,
  comment_text    TEXT NOT NULL,
  likes_count     INTEGER NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Index untuk carian pantas mengikut pos dan masa
CREATE INDEX IF NOT EXISTS idx_feed_comments_post_id ON public.feed_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_feed_comments_created_at ON public.feed_comments(created_at DESC);

-- 3. Aktifkan RLS
ALTER TABLE public.feed_comments ENABLE ROW LEVEL SECURITY;

-- 4. Polisi RLS (Row Level Security)
-- A. Polisi BACA (SELECT): Semua pengguna boleh baca komen pada pos
DROP POLICY IF EXISTS "Feed comments select policy" ON public.feed_comments;
CREATE POLICY "Feed comments select policy"
  ON public.feed_comments FOR SELECT
  USING (true);

-- B. Polisi CIPTA (INSERT): Sesiapa sahaja (anon & authenticated) boleh komen
DROP POLICY IF EXISTS "Feed comments insert policy" ON public.feed_comments;
CREATE POLICY "Feed comments insert policy"
  ON public.feed_comments FOR INSERT
  WITH CHECK (true);

-- C. Polisi PADAM (DELETE): Pemilik komen atau peniaga pemilik pos boleh padam
DROP POLICY IF EXISTS "Feed comments delete policy" ON public.feed_comments;
CREATE POLICY "Feed comments delete policy"
  ON public.feed_comments FOR DELETE
  USING (
    (auth.uid() IS NOT NULL AND user_id = auth.uid()) OR
    EXISTS (
      SELECT 1 FROM public.feed_posts fp
      JOIN public.businesses b ON b.id = fp.business_id
      WHERE fp.id = feed_comments.post_id AND (
        b.owner_user_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.business_id = b.id AND tm.user_id = auth.uid() AND tm.status = 'active')
      )
    )
  );

-- 5. Kebenaran Akses SQL (Permissions)
GRANT SELECT, INSERT ON public.feed_comments TO anon, authenticated;
GRANT ALL ON public.feed_comments TO authenticated;
GRANT ALL ON public.feed_comments TO service_role;

-- 6. Trigger automatik untuk kemas kini comments_count pada feed_posts
CREATE OR REPLACE FUNCTION public.handle_feed_comment_counter()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.feed_posts
    SET comments_count = comments_count + 1
    WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.feed_posts
    SET comments_count = GREATEST(0, comments_count - 1)
    WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_feed_comment_counter ON public.feed_comments;
CREATE TRIGGER trg_feed_comment_counter
  AFTER INSERT OR DELETE ON public.feed_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_feed_comment_counter();
