drop table clientes cascade constraints;
drop table abonos   cascade constraints;
drop table eventos  cascade constraints;
drop table reservas	cascade constraints;

drop sequence seq_abonos;
drop sequence seq_eventos;
drop sequence seq_reservas;


-- Creación de tablas y secuencias

create table clientes(
	NIF	varchar(9) primary key,
	nombre	varchar(20) not null,
	ape1	varchar(20) not null,
	ape2	varchar(20) not null
);


create sequence seq_abonos;

create table abonos(
	id_abono	integer primary key,
	cliente  	varchar(9) references clientes,
	saldo	    integer not null check (saldo>=0)
    );

create sequence seq_eventos;

create table eventos(
	id_evento	integer  primary key,
	nombre_evento		varchar(20),
    fecha       date not null,
	asientos_disponibles	integer  not null
);

create sequence seq_reservas;

create table reservas(
	id_reserva	integer primary key,
	cliente  	varchar(9) references clientes,
    evento      integer references eventos,
	abono       integer references abonos,
	fecha	date not null
);


	
create or replace procedure reservar_evento(
    arg_NIF_cliente varchar,
    arg_nombre_evento varchar,
    arg_fecha date
) is
    v_id_abono abonos.id_abono%type;
    v_saldo abonos.saldo%type;
    v_id_evento eventos.id_evento%type;
    v_asientos eventos.asientos_disponibles%type;
    v_fecha_evento eventos.fecha%type;
    v_fecha_evento1 date := to_date(v_fecha_evento, 'YYYY-MM-DD');

    v_fecha_actual date := to_date('2024-04-08', 'YYYY-MM-DD');
begin
    dbms_output.put_line('Verificando cliente...');
    begin
        select id_abono, saldo into v_id_abono, v_saldo
        from abonos
        where cliente = arg_NIF_cliente
        for update;
    exception
        when no_data_found then
            dbms_output.put_line('Error: Cliente no encontrado.');
            raise_application_error(-20002, 'Cliente inexistente');
    end;

    dbms_output.put_line('Verificando evento...');
    begin
        select id_evento, asientos_disponibles, fecha into v_id_evento, v_asientos, v_fecha_evento
        from eventos
        where nombre_evento = arg_nombre_evento
        for update;
    exception
        when no_data_found then
            dbms_output.put_line('Error: Evento no encontrado.');
            raise_application_error(-20003, 'El evento ' || arg_nombre_evento || ' no existe');
    end;

    if v_saldo <= 0 then
        raise_application_error(-20004, 'Saldo en abono insuficiente');
    end if;
dbms_output.put_line(v_fecha_evento);
dbms_output.put_line(v_fecha_actual);
    if v_fecha_evento1 < v_fecha_actual then
        raise_application_error(-20001, 'No se pueden reservar eventos pasados.');
    elsif v_asientos <= 0 then
        raise_application_error(-20005, 'No hay asientos disponibles para este evento');
    end if;

    dbms_output.put_line('Realizando reserva...');
    update abonos set saldo = saldo - 1 where id_abono = v_id_abono;
    update eventos set asientos_disponibles = asientos_disponibles - 1 where id_evento = v_id_evento;

    insert into reservas (id_reserva, cliente, evento, abono, fecha)
    values (seq_reservas.nextval, arg_NIF_cliente, v_id_evento, v_id_abono, arg_fecha);

    commit;
    dbms_output.put_line('Reserva realizada con éxito.');

exception
    when others then
        dbms_output.put_line('Error inesperado: ' || SQLERRM);
end;
/



------ Deja aquí tus respuestas a las preguntas del enunciado:
-- * P4.1
--
-- * P4.2
--
-- * P4.3
--
-- * P4.4
--
-- * P4.5
-- 


create or replace
procedure reset_seq( p_seq_name varchar )
is
    l_val number;
begin
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by -' || l_val || 
                                                          ' minvalue 0';
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by 1 minvalue 0';

end;
/


create or replace procedure inicializa_test is
begin
  reset_seq( 'seq_abonos' );
  reset_seq( 'seq_eventos' );
  reset_seq( 'seq_reservas' );
        
  
    delete from reservas;
    delete from eventos;
    delete from abonos;
    delete from clientes;
    
       
		
    insert into clientes values ('12345678A', 'Pepe', 'Perez', 'Porras');
    insert into clientes values ('11111111B', 'Beatriz', 'Barbosa', 'Bernardez');
    
    insert into abonos values (seq_abonos.nextval, '12345678A',10);
    insert into abonos values (seq_abonos.nextval, '11111111B',0);
    
    insert into eventos values ( seq_eventos.nextval, 'concierto_la_moda', date '2024-6-27', 200);
    insert into eventos values ( seq_eventos.nextval, 'teatro_impro', date '2024-7-1', 50);

    commit;
end;
/

exec inicializa_test;

-- Completa el test

create or replace procedure test_reserva_evento is
begin
	 
  --caso 1 Reserva correcta, se realiza
  begin
    inicializa_test;
  end;
  
  
  --caso 2 Evento pasado
  begin
    inicializa_test;
  end;
  
  --caso 3 Evento inexistente
  begin
    inicializa_test;
  end;
  

  --caso 4 Cliente inexistente  
  begin
    inicializa_test;
  end;
  
  --caso 5 El cliente no tiene saldo suficiente
  begin
    inicializa_test;
  end;

  
end;
/



set serveroutput on;
exec test_reserva_evento;
