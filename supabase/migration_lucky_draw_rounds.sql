-- 럭키드로우 사이드 이벤트(회차제)를 위한 새 테이블입니다.
-- 지금 운영 중인 참여신청(public.applications, apply.html)과는 완전히 분리되어 있어서
-- 이 마이그레이션을 실행해도 진행 중인 참여신청 접수에는 전혀 영향이 없습니다.
--
-- 만드는 것:
--   1) lucky_draw_rounds  - 회차별 설정(공개상태 / 정원 / 상품 구성)
--   2) lucky_draw_entries - 회차별 응모 데이터 (참여신청과 동일한 항목 구성 + round 구분)
--   3) get_lucky_draw_round_status - 응모 페이지가 열림/마감 상태를 확인하는 공개 함수
--   4) 관리자 조회/삭제/오픈-마감 함수 (비밀번호는 기존 admin.html과 동일한 7890)
--
-- SQL 편집기에서 그대로 실행하세요.

create extension if not exists pgcrypto;

-- 1) 회차 설정 -----------------------------------------------------------
create table if not exists public.lucky_draw_rounds (
  round int primary key,
  is_open boolean not null default false,
  capacity int not null,
  tiers jsonb not null
);

alter table public.lucky_draw_rounds enable row level security;

-- 응모 페이지에서 "지금 몇 회차가 열려있는지 / 정원이 얼마인지 / 상품 구성"을
-- 읽을 수 있어야 하므로 조회만 익명 허용합니다. (수정은 아래 관리자 함수로만 가능)
drop policy if exists "anon can read round settings" on public.lucky_draw_rounds;
create policy "anon can read round settings"
  on public.lucky_draw_rounds
  for select
  to anon
  using (true);

-- 2) 회차별 응모 -----------------------------------------------------------
create table if not exists public.lucky_draw_entries (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  round int not null references public.lucky_draw_rounds(round),
  company text not null,
  department text,
  manager_name text not null,
  "position" text,
  phone text not null,
  email text not null,
  companions jsonb not null default '[]'::jsonb,
  interested_site text,
  privacy_consent boolean not null default false,
  marketing_consent boolean not null default false
);

alter table public.lucky_draw_entries enable row level security;

-- 응모는 익명으로 가능하지만, 조회/수정/삭제는 아래 비밀번호 기반 함수로만 가능합니다.
drop policy if exists "anon can insert lucky draw entries" on public.lucky_draw_entries;
create policy "anon can insert lucky draw entries"
  on public.lucky_draw_entries
  for insert
  to anon
  with check (true);

-- 3) 응모 페이지용 공개 함수 -----------------------------------------------
-- 개인정보는 전혀 노출하지 않고, "지금 열려있는지 / 정원이 얼마나 찼는지"만 알려줍니다.
-- draw2-apply.html이 응모 폼을 보여주기 전에 이 함수로 상태를 먼저 확인합니다.
create or replace function public.get_lucky_draw_round_status(target_round int)
returns table (round int, is_open boolean, capacity int, tiers jsonb, entry_count bigint)
language sql
security definer
set search_path = public
as $$
  select r.round, r.is_open, r.capacity, r.tiers,
         (select count(*) from public.lucky_draw_entries e where e.round = r.round)
  from public.lucky_draw_rounds r
  where r.round = target_round;
$$;

grant execute on function public.get_lucky_draw_round_status(int) to anon;

-- 4) 관리자 함수 -----------------------------------------------------------
-- 특정 회차의 응모 목록 조회 (admin.html의 get_applications와 동일한 패턴)
create or replace function public.get_lucky_draw_entries(input_password text, target_round int)
returns setof public.lucky_draw_entries
language plpgsql
security definer
set search_path = public
as $$
begin
  if input_password is distinct from '7890' then
    raise exception 'invalid password';
  end if;

  return query
    select * from public.lucky_draw_entries
    where round = target_round
    order by created_at desc;
end;
$$;

grant execute on function public.get_lucky_draw_entries(text, int) to anon;

-- 응모 1건 삭제
create or replace function public.delete_lucky_draw_entry(input_password text, target_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if input_password is distinct from '7890' then
    raise exception 'invalid password';
  end if;

  delete from public.lucky_draw_entries where id = target_id;
end;
$$;

grant execute on function public.delete_lucky_draw_entry(text, uuid) to anon;

-- 회차 열기/닫기 (정원이 다 차기 전에도 관리자가 수동으로 잠깐 끊고 싶을 때 사용)
create or replace function public.set_lucky_draw_round_open(input_password text, target_round int, open_state boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if input_password is distinct from '7890' then
    raise exception 'invalid password';
  end if;

  update public.lucky_draw_rounds set is_open = open_state where round = target_round;
end;
$$;

grant execute on function public.set_lucky_draw_round_open(text, int, boolean) to anon;

-- 5) 2차 회차 등록 -----------------------------------------------------------
-- 준비가 끝나기 전 실수로 응모가 열리지 않도록 is_open = false(닫힘) 상태로 만듭니다.
-- 시작할 준비가 되면 관리자 화면에서 열거나,
-- 아래 SQL을 다시 실행해 is_open을 true로 바꾸면 됩니다.
insert into public.lucky_draw_rounds (round, is_open, capacity, tiers)
values (
  2,
  false,
  150,
  '[
    {"rank":"1등","name":"에어팟 프로","count":1},
    {"rank":"2등","name":"헤드셋","count":5},
    {"rank":"3등","name":"손선풍기","count":30},
    {"rank":"4등","name":"기념품","count":40},
    {"rank":"5등","name":"기념품","count":74}
  ]'::jsonb
)
on conflict (round) do update
  set capacity = excluded.capacity,
      tiers = excluded.tiers;

-- 나중에 비밀번호를 바꾸고 싶다면, 이 파일의 세 함수와
-- admin_policy.sql / migration_2026_apply_form.sql의 함수들을 모두 같은 새 비밀번호로 바꿔서
-- 재실행하세요. (전부 같은 값이어야 합니다)
