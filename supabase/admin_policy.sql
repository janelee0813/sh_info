-- schema.sql을 먼저 실행한 뒤, SQL Editor에서 이어서 실행하세요.
--
-- 계정을 따로 만들지 않고 "비밀번호 하나"로만 관리자 데이터를 조회할 수 있게 하는 방식입니다.
-- 아래 함수 안의 'CHANGE_ME_PASSWORD' 부분을 원하는 비밀번호로 바꾼 뒤 실행하세요.
-- (참여신청 폼을 채우는 방문자는 여전히 "입력만 가능"하고, 이 비밀번호 없이는 조회가 불가능합니다.)

create or replace function public.get_applications(input_password text)
returns setof public.applications
language plpgsql
security definer
set search_path = public
as $$
begin
  if input_password is distinct from 'CHANGE_ME_PASSWORD' then
    raise exception 'invalid password';
  end if;

  return query
    select * from public.applications order by created_at desc;
end;
$$;

grant execute on function public.get_applications(text) to anon;

-- 나중에 비밀번호를 바꾸고 싶다면, 위 함수 전체를 다시 실행하되
-- 'CHANGE_ME_PASSWORD' 자리만 새 비밀번호로 바꿔서 재실행하면 됩니다.

-- 페이지를 완전히 없앨 때는 아래 한 줄만 실행하면 접근이 즉시 차단됩니다.
-- drop function if exists public.get_applications(text);
