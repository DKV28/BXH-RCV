-- =====================================================================
--  Web bình chọn áp phích – RCV WPSD 2026
--  Supabase Postgres schema: bảng + RLS + RPC + Realtime
--  Chạy 1 lần trong Supabase → SQL Editor → New query → Run.
--  Mọi ghi/đọc nhạy cảm đi qua RPC SECURITY DEFINER; client (anon key)
--  KHÔNG đọc/ghi trực tiếp bảng votes / staff_roster / app_secrets.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;  -- crypt(), gen_salt()
create extension if not exists unaccent with schema extensions;   -- bỏ dấu tiếng Việt

-- ---------------------------------------------------------------------
-- 1. BẢNG
-- ---------------------------------------------------------------------
create table if not exists public.posters (
  id          bigint generated always as identity primary key,
  name        text not null,
  image_url   text,
  sort_order  int  not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create table if not exists public.votes (
  id             bigint generated always as identity primary key,
  employee_code  text not null unique,          -- 1 mã = 1 phiếu
  employee_name  text not null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table if not exists public.vote_selections (
  vote_id    bigint not null references public.votes(id)   on delete cascade,
  poster_id  bigint not null references public.posters(id) on delete cascade,
  primary key (vote_id, poster_id)
);

create table if not exists public.settings (
  id           int primary key default 1,
  voting_open  boolean not null default false,
  event_name   text    not null default 'RCV WPSD 2026',
  max_choices  int     not null default 3,
  constraint settings_singleton check (id = 1)
);
insert into public.settings(id) values (1) on conflict do nothing;

create table if not exists public.staff_roster (
  employee_code  text primary key,
  employee_name  text not null
);

create table if not exists public.app_secrets (
  id          int primary key default 1,
  admin_hash  text not null,
  constraint app_secrets_singleton check (id = 1)
);

-- ---------------------------------------------------------------------
-- 2. MẬT KHẨU ADMIN
--    Đổi 'CHANGE_ME_admin_pass' thành passphrase của bạn TRƯỚC khi Run.
-- ---------------------------------------------------------------------
insert into public.app_secrets(id, admin_hash)
values (1, extensions.crypt('CHANGE_ME_admin_pass', extensions.gen_salt('bf')))
on conflict (id) do nothing;
-- Đổi mật khẩu sau này:
--   update public.app_secrets set admin_hash = extensions.crypt('mat_khau_moi', extensions.gen_salt('bf')) where id = 1;

-- ---------------------------------------------------------------------
-- 3. ROW LEVEL SECURITY
--    Bật RLS mọi bảng. Chỉ mở SELECT công khai cho posters (active) và
--    settings và vote_selections (không chứa PII). votes/staff_roster/
--    app_secrets: không policy → anon không truy cập trực tiếp được;
--    chỉ RPC SECURITY DEFINER (chạy quyền owner) mới đụng tới.
-- ---------------------------------------------------------------------
alter table public.posters         enable row level security;
alter table public.votes           enable row level security;
alter table public.vote_selections enable row level security;
alter table public.settings        enable row level security;
alter table public.staff_roster    enable row level security;
alter table public.app_secrets     enable row level security;

drop policy if exists posters_read on public.posters;
create policy posters_read on public.posters
  for select using (active = true);

drop policy if exists settings_read on public.settings;
create policy settings_read on public.settings
  for select using (true);

-- Cần cho Supabase Realtime (board nghe thay đổi để re-query kết quả).
-- vote_selections chỉ có vote_id (ẩn danh) + poster_id, không lộ tên/mã.
drop policy if exists vote_selections_read on public.vote_selections;
create policy vote_selections_read on public.vote_selections
  for select using (true);

-- ---------------------------------------------------------------------
-- 4. HÀM TIỆN ÍCH (nội bộ, không cấp quyền cho anon)
-- ---------------------------------------------------------------------
-- Chuẩn hoá tên để đối chiếu: bỏ dấu + trim + lowercase + gộp khoảng trắng.
create or replace function public.norm(t text)
returns text language sql stable set search_path = public, extensions as $$
  select lower(regexp_replace(btrim(extensions.unaccent(coalesce(t, ''))), '\s+', ' ', 'g'));
$$;

-- Kiểm tra passphrase admin.
create or replace function public.admin_check(p_pass text)
returns boolean language sql stable security definer
set search_path = public, extensions as $$
  select exists (
    select 1 from public.app_secrets
    where id = 1 and admin_hash = extensions.crypt(coalesce(p_pass, ''), admin_hash)
  );
$$;

-- ---------------------------------------------------------------------
-- 5. RPC CÔNG KHAI (anon gọi được)
-- ---------------------------------------------------------------------

-- Ghi / cập nhật phiếu theo mã nhân viên (upsert → sửa được đến khi đóng).
create or replace function public.cast_vote(p_code text, p_name text, p_poster_ids bigint[])
returns json language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_open   boolean;
  v_max    int;
  v_vote_id bigint;
  v_n      int;
  v_valid  int;
  v_uniq   int;
begin
  select voting_open, max_choices into v_open, v_max from public.settings where id = 1;
  if not v_open then
    return json_build_object('ok', false, 'error', 'closed');
  end if;

  p_code := nullif(btrim(p_code), '');
  p_name := nullif(btrim(p_name), '');
  if p_code is null or p_name is null then
    return json_build_object('ok', false, 'error', 'missing_code_or_name');
  end if;

  v_n := coalesce(array_length(p_poster_ids, 1), 0);
  if v_n = 0 then
    return json_build_object('ok', false, 'error', 'no_selection');
  end if;
  if v_n > v_max then
    return json_build_object('ok', false, 'error', 'too_many', 'max', v_max);
  end if;

  -- không cho trùng id trong cùng phiếu
  select count(distinct x) into v_uniq from unnest(p_poster_ids) x;
  if v_uniq <> v_n then
    return json_build_object('ok', false, 'error', 'duplicate_selection');
  end if;

  -- mọi id phải là áp phích đang active
  select count(*) into v_valid from public.posters
    where id = any(p_poster_ids) and active = true;
  if v_valid <> v_n then
    return json_build_object('ok', false, 'error', 'invalid_poster');
  end if;

  insert into public.votes(employee_code, employee_name)
    values (p_code, p_name)
    on conflict (employee_code)
    do update set employee_name = excluded.employee_name, updated_at = now()
    returning id into v_vote_id;

  delete from public.vote_selections where vote_id = v_vote_id;
  insert into public.vote_selections(vote_id, poster_id)
    select v_vote_id, unnest(p_poster_ids);

  return json_build_object('ok', true, 'vote_id', v_vote_id);
end;
$$;

-- Nạp lại phiếu hiện tại của 1 mã để chủ mã sửa. Mã = "mật khẩu cá nhân".
create or replace function public.get_my_vote(p_code text)
returns json language plpgsql security definer
set search_path = public as $$
declare
  v_id   bigint;
  v_name text;
  v_ids  bigint[];
begin
  p_code := nullif(btrim(p_code), '');
  if p_code is null then return json_build_object('found', false); end if;
  select id, employee_name into v_id, v_name from public.votes where employee_code = p_code;
  if v_id is null then return json_build_object('found', false); end if;
  select coalesce(array_agg(poster_id), '{}') into v_ids
    from public.vote_selections where vote_id = v_id;
  return json_build_object('found', true, 'name', v_name, 'poster_ids', v_ids);
end;
$$;

-- Kết quả tổng hợp cho leaderboard (không lộ tên/mã người vote).
create or replace function public.get_results()
returns json language sql security definer stable
set search_path = public as $$
  select coalesce(json_agg(r order by r.votes desc, r.name asc), '[]'::json)
  from (
    select p.id, p.name, coalesce(c.cnt, 0)::int as votes
    from public.posters p
    left join (
      select poster_id, count(*) as cnt
      from public.vote_selections group by poster_id
    ) c on c.poster_id = p.id
    where p.active = true
  ) r;
$$;

-- Trạng thái công khai cho các trang.
create or replace function public.get_state()
returns json language sql security definer stable
set search_path = public as $$
  select json_build_object(
    'voting_open', s.voting_open,
    'event_name',  s.event_name,
    'max_choices', s.max_choices,
    'ballots',     (select count(*) from public.votes)
  ) from public.settings s where s.id = 1;
$$;

-- ---------------------------------------------------------------------
-- 6. RPC ADMIN (bảo vệ bằng passphrase bên trong; an toàn khi cấp cho anon)
-- ---------------------------------------------------------------------
create or replace function public.admin_set_voting_open(p_pass text, p_open boolean)
returns json language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.admin_check(p_pass) then return json_build_object('ok', false, 'error', 'unauthorized'); end if;
  update public.settings set voting_open = p_open where id = 1;
  return json_build_object('ok', true, 'voting_open', p_open);
end; $$;

create or replace function public.admin_list_posters(p_pass text)
returns json language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.admin_check(p_pass) then return json_build_object('ok', false, 'error', 'unauthorized'); end if;
  -- Không trả cả ảnh (data URI có thể lớn) trong danh sách; chỉ báo có ảnh hay không.
  return json_build_object('ok', true, 'posters', coalesce((
    select json_agg(json_build_object(
      'id', p.id, 'name', p.name, 'has_image', (p.image_url is not null),
      'sort_order', p.sort_order, 'active', p.active,
      'votes', (select count(*) from public.vote_selections s where s.poster_id = p.id)
    ) order by p.sort_order, p.id) from public.posters p
  ), '[]'::json));
end; $$;

-- Lấy đầy đủ 1 áp phích (kèm ảnh) để sửa.
create or replace function public.admin_get_poster(p_pass text, p_id bigint)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare v json;
begin
  if not public.admin_check(p_pass) then return json_build_object('ok', false, 'error', 'unauthorized'); end if;
  select json_build_object('ok', true, 'poster', json_build_object(
    'id', id, 'name', name, 'image_url', image_url, 'sort_order', sort_order, 'active', active))
  into v from public.posters where id = p_id;
  return coalesce(v, json_build_object('ok', false, 'error', 'not_found'));
end; $$;

-- Thêm/sửa áp phích. Quy ước ảnh (p_image_url):
--   NULL            -> giữ nguyên ảnh cũ (khi sửa) / không ảnh (khi thêm)
--   '' (rỗng)       -> xoá ảnh
--   data URI / link -> đặt ảnh mới
create or replace function public.admin_upsert_poster(
  p_pass text, p_id bigint, p_name text, p_image_url text, p_sort_order int, p_active boolean)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare v_id bigint;
begin
  if not public.admin_check(p_pass) then return json_build_object('ok', false, 'error', 'unauthorized'); end if;
  if nullif(btrim(p_name), '') is null then return json_build_object('ok', false, 'error', 'name_required'); end if;
  if p_id is null then
    insert into public.posters(name, image_url, sort_order, active)
      values (btrim(p_name),
              case when p_image_url is null or btrim(p_image_url) = '' then null else p_image_url end,
              coalesce(p_sort_order, 0), coalesce(p_active, true))
      returning id into v_id;
  else
    update public.posters
      set name = btrim(p_name),
          image_url = case
            when p_image_url is null then image_url          -- giữ ảnh cũ
            when btrim(p_image_url) = '' then null            -- xoá ảnh
            else p_image_url end,                             -- ảnh mới
          sort_order = coalesce(p_sort_order, 0),
          active = coalesce(p_active, true)
      where id = p_id returning id into v_id;
  end if;
  return json_build_object('ok', true, 'id', v_id);
end; $$;

create or replace function public.admin_delete_poster(p_pass text, p_id bigint)
returns json language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.admin_check(p_pass) then return json_build_object('ok', false, 'error', 'unauthorized'); end if;
  delete from public.posters where id = p_id;
  return json_build_object('ok', true);
end; $$;

-- Upload danh sách nhân viên chính thức (thay toàn bộ). p_rows = [{code,name},...]
create or replace function public.admin_upload_roster(p_pass text, p_rows jsonb)
returns json language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.admin_check(p_pass) then return json_build_object('ok', false, 'error', 'unauthorized'); end if;
  delete from public.staff_roster;
  insert into public.staff_roster(employee_code, employee_name)
    select btrim(x->>'code'), btrim(x->>'name')
    from jsonb_array_elements(p_rows) x
    where nullif(btrim(x->>'code'), '') is not null
    on conflict (employee_code) do update set employee_name = excluded.employee_name;
  return json_build_object('ok', true, 'count', (select count(*) from public.staff_roster));
end; $$;

-- Xem toàn bộ phiếu thô (cho admin rà soát / export).
create or replace function public.admin_get_raw_votes(p_pass text)
returns json language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.admin_check(p_pass) then return json_build_object('ok', false, 'error', 'unauthorized'); end if;
  return json_build_object('ok', true, 'votes', coalesce((
    select json_agg(json_build_object(
      'code', v.employee_code, 'name', v.employee_name, 'updated_at', v.updated_at,
      'posters', (select coalesce(json_agg(p.name order by p.name), '[]'::json)
                  from public.vote_selections s join public.posters p on p.id = s.poster_id
                  where s.vote_id = v.id)
    ) order by v.updated_at desc) from public.votes v
  ), '[]'::json));
end; $$;

-- Kết quả CUỐI đã đối chiếu roster: chỉ tính phiếu có (mã) trong roster và
-- tên khớp (đã chuẩn hoá). Trả kèm danh sách phiếu bị loại + lý do.
create or replace function public.admin_get_final_results(p_pass text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare v_out json;
begin
  if not public.admin_check(p_pass) then return json_build_object('ok', false, 'error', 'unauthorized'); end if;
  with valid as (
    select v.id
    from public.votes v
    join public.staff_roster r
      on r.employee_code = v.employee_code
     and public.norm(r.employee_name) = public.norm(v.employee_name)
  )
  select json_build_object(
    'ok', true,
    'valid_count', (select count(*) from valid),
    'total_count', (select count(*) from public.votes),
    'results', coalesce((
      select json_agg(json_build_object('id', p.id, 'name', p.name, 'votes', coalesce(c.cnt, 0)::int)
                       order by coalesce(c.cnt, 0) desc, p.name)
      from public.posters p
      left join (
        select s.poster_id, count(*) cnt from public.vote_selections s
        where s.vote_id in (select id from valid) group by s.poster_id
      ) c on c.poster_id = p.id
      where p.active = true
    ), '[]'::json),
    'invalid', coalesce((
      select json_agg(json_build_object(
        'code', v.employee_code, 'name', v.employee_name,
        'reason', case when r.employee_code is null then 'code_not_in_roster' else 'name_mismatch' end)
        order by v.employee_code)
      from public.votes v
      left join public.staff_roster r on r.employee_code = v.employee_code
      where v.id not in (select id from valid)
    ), '[]'::json)
  ) into v_out;
  return v_out;
end; $$;

-- ---------------------------------------------------------------------
-- 7. CẤP QUYỀN (tường minh — không phụ thuộc grant mặc định của Supabase)
-- ---------------------------------------------------------------------
-- Đọc trực tiếp (client dùng): posters (RLS lọc active), settings, vote_selections (realtime).
grant usage on schema public to anon, authenticated;
grant select on public.posters, public.settings, public.vote_selections to anon, authenticated;

-- Chặn cứng mọi truy cập trực tiếp vào bảng nhạy cảm (chỉ RPC SECURITY DEFINER đụng tới).
revoke all on public.votes        from anon, authenticated, public;
revoke all on public.staff_roster from anon, authenticated, public;
revoke all on public.app_secrets  from anon, authenticated, public;

-- Hàm nội bộ: KHÔNG cho gọi trực tiếp (tránh brute-force passphrase).
revoke execute on function public.admin_check(text) from public;
revoke execute on function public.norm(text)        from public;

grant execute on function public.cast_vote(text, text, bigint[])           to anon, authenticated;
grant execute on function public.get_my_vote(text)                          to anon, authenticated;
grant execute on function public.get_results()                             to anon, authenticated;
grant execute on function public.get_state()                               to anon, authenticated;
grant execute on function public.admin_set_voting_open(text, boolean)       to anon, authenticated;
grant execute on function public.admin_list_posters(text)                   to anon, authenticated;
grant execute on function public.admin_get_poster(text, bigint)             to anon, authenticated;
grant execute on function public.admin_upsert_poster(text, bigint, text, text, int, boolean) to anon, authenticated;
grant execute on function public.admin_delete_poster(text, bigint)          to anon, authenticated;
grant execute on function public.admin_upload_roster(text, jsonb)           to anon, authenticated;
grant execute on function public.admin_get_raw_votes(text)                  to anon, authenticated;
grant execute on function public.admin_get_final_results(text)              to anon, authenticated;
-- KHÔNG cấp admin_check / norm cho anon (chỉ dùng nội bộ).

-- ---------------------------------------------------------------------
-- 8. REALTIME
--    Board nghe INSERT/UPDATE/DELETE trên vote_selections để re-query kết quả.
-- ---------------------------------------------------------------------
do $$
begin
  begin
    alter publication supabase_realtime add table public.vote_selections;
  exception
    when duplicate_object then null;  -- đã có trong publication
    when undefined_object then null;  -- publication chưa tồn tại (bản self-host cũ)
  end;
end $$;

-- Xong. Vào admin.html bằng passphrase để thêm áp phích và mở bình chọn.
