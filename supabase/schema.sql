-- Supabase SQL 편집기(SQL Editor)에서 그대로 실행하세요.
-- 참여신청 폼(기업명/담당자/연락처 등)을 저장할 테이블과,
-- 익명 사용자는 "입력만 가능, 조회는 불가능"하도록 하는 보안 정책(RLS)을 함께 생성합니다.

create extension if not exists pgcrypto;

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  company text not null,
  manager_name text not null,
  "position" text,
  phone text not null,
  email text not null,
  headcount text,
  interests text[],
  consent boolean not null default false
);

alter table public.applications enable row level security;

-- 익명(anon) 키로 접수는 가능하지만, 조회/수정/삭제는 불가능하도록 제한합니다.
create policy "anon can insert applications"
  on public.applications
  for insert
  to anon
  with check (true);
