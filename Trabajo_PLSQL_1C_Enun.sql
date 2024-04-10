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
	
-- Procedimiento a implementar para realizar la reserva

create or replace procedure reservar_evento(
    arg_NIF_cliente varchar, -- Id del cliente
    arg_nombre_evento varchar, -- nombre del evento
    arg_fecha date -- Fecha en la que se ha realizado la reserva
) is
    v_id_abono abonos.id_abono%type;
    v_saldo abonos.saldo%type;
    v_id_evento eventos.id_evento%type;
    v_asientos eventos.asientos_disponibles%type;
    v_fecha_evento eventos.fecha%type;
begin
    begin
        -- Extraemos el id abono y el saldo de este del ciente que ha realizado 
        -- la reserva y bloqueamos la fila.
        select id_abono, saldo into v_id_abono, v_saldo
        from abonos
        where cliente = arg_NIF_cliente
        for update;
    exception
        -- Capturamos una exepcion si no existe el cliente
        when no_data_found then
            -- Los rollback que se ejecutan junto a las ecepciones liberan las 
            -- filas bloqueadas            
            rollback;
            raise_application_error(-20002, 'Cliente inexistente');
    end;

    begin
        -- Extraemos el id evento, los asientos disponibles y la fecha del evento
        -- y bloqueamos la fila
        select id_evento, asientos_disponibles, fecha into v_id_evento, v_asientos, v_fecha_evento
        from eventos
        where nombre_evento = arg_nombre_evento 
        for update;
    exception
        -- Capturamos una exepcion si no existe el evento
        when no_data_found then
            rollback;
            raise_application_error(-20003, 'El evento ' || arg_nombre_evento || ' no existe');
    end;

    -- Comprobamos si el cliente tiene saldo en el abono en caso negativo lanzamos un error
    if v_saldo <= 0 then
        rollback;
        raise_application_error(-20004, 'Saldo en abono insuficiente');
    end if;
    
    -- Comprobamos si la reserva se ha relizado antes de que tome lugar el evento,
    -- si es asi comprobamos si hay asientos disponibles.
    -- En caso de que cualquiera de los dos falle se lanza un error
    if v_fecha_evento < arg_fecha then
        rollback;
        raise_application_error(-20001, 'No se pueden reservar eventos pasados.');
    elsif v_asientos <= 0 then
        rollback;
        raise_application_error(-20005, 'No hay asientos disponibles para este evento');
    end if;
    
    -- Decrementamos uno al saldo del abono del cliente y a los asientos del evento
    update abonos set saldo = saldo - 1 where id_abono = v_id_abono;
    update eventos set asientos_disponibles = asientos_disponibles - 1 where id_evento = v_id_evento;
    
    -- Insartamos la reserva en al tabla.
    insert into reservas (id_reserva, cliente, evento, abono, fecha)
    values (seq_reservas.nextval, arg_NIF_cliente, v_id_evento, v_id_abono, arg_fecha);

    commit; -- Se liberan todas las fila bloqueadas y sa guarda el cabio
end;
/

------ Deja aquí tus respuestas a las preguntas del enunciado:
-- * P4.1 
-- No tendría porque mantenerse la consistencia debido a que pueden haber condiciones de correra entre varios usuarios, para ellos hemos implementado
-- una estrategia defensiva utilizando Select for Update para bloquear el evento para evitar estas condiciones. Por lo que se debería manatener la 
-- consistencia
-- * P4.2 
-- No debido a que al utiizar select for update bloquea que otros procesos concurrentemente hagan otra select for update, por lo que si concurrentemente
-- otro usuario todavia no ha insertado su reserva no se podra hacer una select for update y por lo tanto no habrá problemas dado que esperara a que
-- acabe la transción.
-- * P4.3
-- Hemos utilizado una estrategia de programación defensiva al comprobar con una select for update antes de hacer ninguna inserción, y nosotros lanzar la excepción
-- antes de que el programa la lanze cuando ocurre un error, así evitamos condiciones de carrera y mantenemos la consistencia de los datos.
-- * P4.4
-- Se puede ver en los select for update y las condiciones de después donde comprobamos primero si ocurre algún error y lanzamos la excepción, no 
-- esperamos a que surjan los errores al insertarlo siempre comprobamos antes.
-- * P4.5
-- Nosotros hemos utilizado select for update provocando bloqueos, una estrategia defensiva,  la hemos considerado la mejor opción porque el tiempo que va a tardar en ejecutarse
-- va a ser mínimo (dado que ejectar todos los test tarda 0.071s) y mantenemos la consistencia. Hemos considerado que cuando un usuario llama a la función tiene ya
-- decidido como quiere hacer la reserva, por lo que al tenerlo claro no debería tardar mas que el tiempo de ejecutar la función.
-- Por otro lado se podría haber utilizado una estrategia mas agresiva.
-- Nosotros se nos ocurre mantener nuestro programa similar, eliminando los select for update por select sin mas, haciendo las comprobaciones necesarias antes de insertar
-- pero a la hora de insertar añadiriamos nuevas excepciónes por si varios usuarios concurrentemente interfieren con la misma reserva, y tienen un errores como no complir
-- la condición de saldo positivo que hay en la creación de la tabla abonos check (saldo>=0)  o dup_val_on_index. También añadiriamos en la tabla de eventos un 
-- check (asientos_disponibles>=0) para comprobar también que haya asientos disponibles a la hora de hacer la inserción. 
-- Aun así cremos que mientras se restan los asientos disponibles creemos que puede haber algún estado inconsistente, por lo que hemos preferido utlizar una estrategia defensiva
--Procedimiento reservar_evento(arg_NIF_cliente, arg_nombre_evento, arg_fecha):
--    1. Consultar y validar la existencia del cliente y su saldo.
--    2. Consultar y validar la existencia del evento, la fecha y los asientos disponibles.
--    3. Si el saldo es suficiente y hay asientos disponibles, proceder:
--       a. Actualizar el saldo en la tabla abonos.
--       b. Actualizar los asientos disponibles en la tabla eventos.
--       c. Intentar insertar la nueva reserva en la tabla reservas.
--    4. Manejar posibles excepciones de conflicto.
--    5. Si ocurre cualquier excepción, realizar rollback.
--    6. Si todo es exitoso, confirmar los cambios con commit.

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
    -- Caso 1: Reserva correcta, se realiza
    begin
        inicializa_test;
        reservar_evento('12345678A', 'concierto_la_moda', '08/04/2024');
        dbms_output.put_line('Test 1 pasado: Reserva realizada correctamente.');
    exception 
      when others then
        dbms_output.put_line('Test 1 fallido: ' || SQLERRM);
    end;

    -- Caso 2: Evento pasado
    begin
        inicializa_test;
        reservar_evento('12345678A', 'concierto_la_moda', '22/03/2025');
    exception 
      when others then
        if SQLCODE = -20001 then
            dbms_output.put_line('Test 2 pasado: Error correcto al reservar evento pasado.');
        else
            dbms_output.put_line('Test 2 fallido: ' || SQLERRM);
        end if;
    end;

    -- Caso 3: Evento inexistente
    begin
        inicializa_test;
        reservar_evento('12345678A', 'evento_fantasma', '08/04/2024');
    exception 
      when others then
        if SQLCODE = -20003 then
            dbms_output.put_line('Test 3 pasado: Error correcto al reservar evento inexistente.');
        else
            dbms_output.put_line('Test 3 fallido: ' || SQLERRM);
        end if;
    end;

    -- Caso 4: Cliente inexistente
    begin
        inicializa_test;
        reservar_evento('99999999X', 'concierto_la_moda', '08/04/2024');
    exception 
      when others then
        if SQLCODE = -20002 then
            dbms_output.put_line('Test 4 pasado: Error correcto al reservar con cliente inexistente.');
        else
            dbms_output.put_line('Test 4 fallido: ' || SQLERRM);
        end if;
    end;

    -- Caso 5: El cliente no tiene saldo suficiente
    begin
        inicializa_test;
        reservar_evento('11111111B', 'concierto_la_moda', '08/04/2024');
    exception 
      when others then
        if SQLCODE = -20004 then
            dbms_output.put_line('Test 5 pasado: Error correcto al reservar sin saldo suficiente.');
        else
            dbms_output.put_line('Test 5 fallido: ' || SQLERRM);
        end if;
    end;
end;
/

set serveroutput on;
exec test_reserva_evento;