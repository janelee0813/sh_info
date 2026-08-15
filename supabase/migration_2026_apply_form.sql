-- 참여신청 양식 개편(2026 SH 마곡일반산업단지 매각설명회)에 맞춰
-- 이미 만들어져 있는 applications 테이블의 구조를 바꾸는 마이그레이션입니다.
-- schema.sql, admin_policy.sql을 이미 실행해 운영 중인 테이블에 대해서만 실행하세요.
-- (테이블을 아직 만든 적이 없다면 이 파일 대신 schema.sql을 실행하면 됩니다.)
--
-- ⚠️ 주의: headcount, interests 컬럼은 삭제됩니다.
-- 예전 설문의 "참석인원 / 관심분야" 데이터가 필요하다면, 실행 전에 관리자 화면에서
-- CSV로 먼저 백업해두세요. 나머지 컬럼(기업명/담당자/연락처/이메일 등)과 기존 동의 여부는
-- 새 컬럼으로 그대로 옮겨지며 삭제되지 않습니다.

-- 기존 "동의(consent)" 컬럼은 의미가 같은 "개인정보 수집·이용 동의(필수)"이므로
-- 데이터를 유지한 채 이름만 바꿉니다.
alter table public.applications rename column consent to privacy_consent;

alter table public.applications
  add column if not exists department text,
  add column if not exists companions jsonb not null default '[]'::jsonb,
  add column if not exists interested_site text,
  add column if not exists marketing_consent boolean not null default false;

alter table public.applications
  drop column if exists headcount,
  drop column if exists interests;

-- 관리자 화면에서 신청 1건을 삭제할 때 쓰는 비밀번호 기반 함수입니다.
-- admin_policy.sql에서 설정한 것과 "동일한 비밀번호"를 아래 CHANGE_ME_PASSWORD 자리에 넣고 실행하세요.
create or replace function public.delete_application(input_password text, target_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if input_password is distinct from 'CHANGE_ME_PASSWORD' then
    raise exception 'invalid password';
  end if;

  delete from public.applications where id = target_id;
end;
$$;

grant execute on function public.delete_application(text, uuid) to anon;

-- 나중에 비밀번호를 바꾸고 싶다면, 위 함수 전체를 다시 실행하되
-- 'CHANGE_ME_PASSWORD' 자리만 새 비밀번호로 바꿔서 재실행하면 됩니다.
-- (get_applications 함수의 비밀번호도 같은 값으로 맞춰두는 것을 권장합니다.)
