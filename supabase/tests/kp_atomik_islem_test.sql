-- SQL Editor'da migration'dan SONRA tek parça çalıştırılır.
-- Tüm kullanıcılar, kayıtlar ve test istekleri sonunda ROLLBACK ile geri alınır.
begin;
insert into auth.users(id, email, aud, role)
values ('f841a25f-0a9a-4ee4-91e4-d54b04a31c01', 'kp-transaction-test@example.invalid', 'authenticated', 'authenticated');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'f841a25f-0a9a-4ee4-91e4-d54b04a31c01', true);
select set_config('request.jwt.claims', '{"sub":"f841a25f-0a9a-4ee4-91e4-d54b04a31c01","role":"authenticated"}', true);

do $$
declare
  uid uuid := 'f841a25f-0a9a-4ee4-91e4-d54b04a31c01';
  kid text := 'f841a25f-0a9a-4ee4-91e4-d54b04a31c02';
  rid uuid := 'f841a25f-0a9a-4ee4-91e4-d54b04a31c03';
  op jsonb;
  hata boolean;
  sonuc text;
begin
  op := jsonb_build_array(jsonb_build_object('tablo','kumesler','tur','ekle','id',kid,
    'veri',jsonb_build_object('ad','İlk','tur','tavuk','irklar','[]'::jsonb,'hareketler','[]'::jsonb,'not_',null)));
  perform public.kp_atomik_islem(rid, op, uid);
  perform public.kp_atomik_islem(rid, op, uid);
  if (select count(*) from public.kumesler where id::text = kid) <> 1 then
    raise exception 'TEST BAŞARISIZ: tekrar gönderim çift kayıt oluşturdu';
  end if;

  hata := false;
  begin
    perform public.kp_atomik_islem(gen_random_uuid(),
      jsonb_build_array(
        jsonb_build_object('tablo','kumesler','tur','guncelle','id',kid,'veri',jsonb_build_object('ad','Yarım'),
          'beklenen',jsonb_build_object('ad','İlk')),
        jsonb_build_object('tablo','izin_verilmeyen','tur','ekle','id',gen_random_uuid()::text,'veri','{}'::jsonb)
      ),uid);
  exception when others then hata := true;
  end;
  select ad into sonuc from public.kumesler where id::text = kid;
  if not hata or sonuc <> 'İlk' then raise exception 'TEST BAŞARISIZ: yarım işlem geri alınmadı'; end if;

  hata := false;
  begin
    perform public.kp_atomik_islem(gen_random_uuid(),
      jsonb_build_array(jsonb_build_object('tablo','kumesler','tur','guncelle','id',kid,
        'veri',jsonb_build_object('ad','Eski cihaz'), 'beklenen',jsonb_build_object('ad','Farklı değer'))),uid);
  exception when serialization_failure then hata := true;
  end;
  if not hata then raise exception 'TEST BAŞARISIZ: eski veriyle yazma kabul edildi'; end if;

  hata := false;
  begin
    perform public.kp_atomik_islem(gen_random_uuid(),op,'f841a25f-0a9a-4ee4-91e4-d54b04a31c09');
  exception when others then hata := true;
  end;
  if not hata then raise exception 'TEST BAŞARISIZ: yanlış kullanıcı kimliği kabul edildi'; end if;

  hata := false;
  begin
    perform public.kp_atomik_islem(rid, '[]'::jsonb, uid);
  exception when others then hata := true;
  end;
  if not hata then raise exception 'TEST BAŞARISIZ: aynı istek kimliği farklı içerikle kabul edildi'; end if;

  hata := false;
  begin
    perform public.kp_atomik_islem(gen_random_uuid(),
      jsonb_build_array(jsonb_build_object('tablo','kumesler','id',kid,'veri',jsonb_build_object('ad','İzinsiz'))),uid);
  exception when others then hata := true;
  end;
  if not hata then raise exception 'TEST BAŞARISIZ: işlem türü olmayan istek kabul edildi'; end if;
  raise notice '6 transaction testi başarılı. Tüm test verileri geri alınacak.';
end;
$$;
rollback;
