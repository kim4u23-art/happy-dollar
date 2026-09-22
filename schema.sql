-- ============================================================
-- Happy Dollar — 로그인/회원가입 + 관리자 수동 승인 스키마
-- Supabase 대시보드 → SQL Editor 에서 이 전체 내용을 붙여넣고 Run 하세요.
--
-- 이전에 라이선스 키 버전(licenses 테이블)을 실행하셨다면
-- 더 이상 쓰지 않으니 지워도 됩니다: drop table if exists licenses;
-- ============================================================

-- 1. 프로필 테이블 — 회원가입하면 자동으로 한 행씩 생성됨
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  phone text,
  depositor_name text,          -- 입금자명(본인과 다를 경우)
  amount int,                    -- 요청 시점의 금액(참고용)
  status text not null default 'pending',   -- 'pending' | 'active' | 'revoked'
  requested_at timestamptz,      -- "입금 완료" 버튼을 누른 시각
  approved_at timestamptz,       -- 관리자가 승인한 시각
  created_at timestamptz default now()
);

-- 2. RLS 활성화
alter table profiles enable row level security;

-- 본인 프로필(상태 포함)만 조회 가능 — 로그인 후 "승인됐는지" 확인할 때 사용
drop policy if exists "profiles_select_own" on profiles;
create policy "profiles_select_own" on profiles
  for select using (auth.uid() = id);

-- 주의: update/insert 정책은 일부러 만들지 않았습니다.
-- 즉 사용자는 자기 status를 직접 'active'로 바꿀 수 없고,
-- 아래 두 함수(트리거/RPC)를 통해서만 데이터가 들어가고 바뀝니다.

-- 3. 회원가입 시 profiles 행 자동 생성
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, name)
  values (new.id, new.email, new.raw_user_meta_data->>'name');
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- 4. "입금 완료" 버튼을 누르면 호출되는 함수
--    본인 행의 연락처/입금자명/요청시각만 채워넣고, status는 건드리지 않음
--    (status를 active로 바꾸는 건 오직 관리자만 — Table Editor에서 직접)
create or replace function submit_payment_info(
  p_phone text,
  p_depositor_name text,
  p_amount int
) returns void as $$
begin
  update profiles
    set phone = p_phone,
        depositor_name = p_depositor_name,
        amount = p_amount,
        requested_at = now()
    where id = auth.uid();
end;
$$ language plpgsql security definer;

grant execute on function submit_payment_info(text, text, int) to authenticated;

-- ============================================================
-- 입금 확인 후 승인하는 방법 (관리자 = 당신)
--
-- 방법 A) Supabase 대시보드 → Table Editor → profiles 테이블에서
--         해당 사용자 행을 찾아 status를 'pending' → 'active' 로 수정
--
-- 방법 B) SQL Editor에서 이메일로 찾아 승인
--   update profiles set status = 'active', approved_at = now()
--   where email = '고객이메일@example.com';
--
-- 승인 대기 중인 목록 한눈에 보기:
--   select email, name, phone, depositor_name, amount, requested_at
--   from profiles where status = 'pending' and requested_at is not null
--   order by requested_at desc;
--
-- 승인 후에는 고객이 앱에서 "승인됐는지 다시 확인하기" 버튼을 누르거나
-- 다시 로그인하면 바로 이용 가능합니다.
-- ============================================================
