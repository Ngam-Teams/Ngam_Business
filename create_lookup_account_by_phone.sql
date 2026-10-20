-- =========================================================================================
-- NGAM ECOSYSTEM - ACCOUNT LOOKUP & RECOVERY BY PHONE NUMBER
-- Fungsi: Membolehkan pengguna & peniaga yang terlupa emel mencari akaun menggunakan
--         nombor telefon dan menerima pautan reset kata laluan secara percuma ke emel berdaftar.
-- Digunakan oleh:
-- 1. Ngam Business (Merchant App)
-- 2. Ngam (Consumer / Customer App)
-- =========================================================================================

CREATE OR REPLACE FUNCTION public.lookup_account_by_phone(phone_input TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  clean_phone TEXT;
  found_user RECORD;
  found_business RECORD;
  target_email TEXT;
  masked_email TEXT;
  user_name_val TEXT;
  user_part TEXT;
  domain_part TEXT;
  masked_user TEXT;
BEGIN
  IF phone_input IS NULL OR trim(phone_input) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Sila masukkan nombor telefon yang sah.'
    );
  END IF;

  -- 1. Bersihkan nombor telefon (hanya simpan digit)
  clean_phone := regexp_replace(phone_input, '[^0-9]', '', 'g');

  -- Buang awalan negara 60 atau 0 untuk standardisasi padanan tempatan
  IF clean_phone LIKE '60%' THEN
    clean_phone := substring(clean_phone from 3);
  END IF;
  IF clean_phone LIKE '0%' THEN
    clean_phone := substring(clean_phone from 2);
  END IF;

  IF length(clean_phone) < 7 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Nombor telefon terlalu pendek.'
    );
  END IF;

  -- 2. Cari dalam public.users (Pelanggan & Staf/Peniaga)
  SELECT u.id, u.user_email, u.user_name, u.role
  INTO found_user
  FROM public.users u
  WHERE u.user_email IS NOT NULL 
    AND u.user_email <> ''
    AND (
      regexp_replace(COALESCE(u.user_phone, ''), '[^0-9]', '', 'g') LIKE '%' || clean_phone
      OR regexp_replace(COALESCE(u.user_phone, ''), '[^0-9]', '', 'g') = clean_phone
    )
  LIMIT 1;

  IF found_user.user_email IS NOT NULL AND found_user.user_email <> '' THEN
    target_email := found_user.user_email;
    user_name_val := found_user.user_name;
  ELSE
    -- 3. Cari dalam public.businesses (Peniaga / Kedai)
    SELECT b.business_email, b.business_name, au.email as owner_auth_email
    INTO found_business
    FROM public.businesses b
    LEFT JOIN auth.users au ON au.id = b.owner_user_id
    WHERE regexp_replace(COALESCE(b.business_phone, ''), '[^0-9]', '', 'g') LIKE '%' || clean_phone
       OR regexp_replace(COALESCE(b.business_phone, ''), '[^0-9]', '', 'g') = clean_phone
    LIMIT 1;

    IF found_business.owner_auth_email IS NOT NULL AND found_business.owner_auth_email <> '' THEN
      target_email := found_business.owner_auth_email;
      user_name_val := found_business.business_name;
    ELSIF found_business.business_email IS NOT NULL AND found_business.business_email <> '' THEN
      target_email := found_business.business_email;
      user_name_val := found_business.business_name;
    END IF;
  END IF;

  -- 4. Semak auth.users secara terus jika masih belum ditemui
  IF target_email IS NULL THEN
    SELECT au.email
    INTO target_email
    FROM auth.users au
    WHERE regexp_replace(COALESCE(au.phone, ''), '[^0-9]', '', 'g') LIKE '%' || clean_phone
    LIMIT 1;
  END IF;

  -- Jika tiada rekod dijumpai
  IF target_email IS NULL OR target_email = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Tiada akaun dijumpai untuk nombor telefon tersebut.'
    );
  END IF;

  -- 5. Topengkan alamat emel (Masking) untuk keselamatan privasi pengguna
  -- Contoh: ausirfan06@gmail.com -> au*****06@gmail.com
  user_part := split_part(target_email, '@', 1);
  domain_part := split_part(target_email, '@', 2);

  IF length(user_part) <= 2 THEN
    masked_user := substring(user_part from 1 for 1) || '***';
  ELSIF length(user_part) <= 4 THEN
    masked_user := substring(user_part from 1 for 1) || '***' || substring(user_part from length(user_part) for 1);
  ELSE
    masked_user := substring(user_part from 1 for 2) || '*****' || substring(user_part from length(user_part) - 1 for 2);
  END IF;

  masked_email := masked_user || '@' || domain_part;

  RETURN jsonb_build_object(
    'success', true,
    'email', target_email,
    'masked_email', masked_email,
    'name', COALESCE(user_name_val, 'Pengguna Ngam')
  );
END;
$$;

-- Berikan kebenaran laksana kepada pengguna awam (anon) & berdaftar (authenticated)
GRANT EXECUTE ON FUNCTION public.lookup_account_by_phone(TEXT) TO anon, authenticated;
