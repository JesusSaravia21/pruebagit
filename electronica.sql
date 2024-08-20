-- phpMyAdmin SQL Dump
-- version 5.0.2
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1:3306
-- Tiempo de generación: 02-01-2022 a las 03:13:34
-- Versión del servidor: 5.7.31
-- Versión de PHP: 7.3.21

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `electronica`
--

DELIMITER $$
--
-- Procedimientos
--
DROP PROCEDURE IF EXISTS `actualizar_precio_producto`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `actualizar_precio_producto` (`n_cantidad` INT, `n_precio` DECIMAL(10,2), `codigo` VARCHAR(11))  BEGIN
	DECLARE nueva_existencia int;
    DECLARE nuevo_total decimal(10,2);
    DECLARE nuevo_precio decimal(10,2);
    
    DECLARE cant_actual int;
    DECLARE pre_actual decimal(10,2);
    
    DECLARE actual_existencia int;
    DECLARE actual_precio decimal(10,2);
    
    SELECT precio,stock INTO actual_precio,actual_existencia FROM productos WHERE codproducto = codigo;
    SET nueva_existencia = actual_existencia + n_cantidad;
    SET nuevo_total = (actual_existencia * actual_precio) + (n_cantidad * n_precio);
    SET nuevo_precio = nuevo_total / nueva_existencia;
    
    UPDATE productos SET stock = nueva_existencia, precio = nuevo_precio WHERE codproducto = codigo;
    
    SELECT nueva_existencia,nuevo_precio;
    
  END$$

DROP PROCEDURE IF EXISTS `add_detalle_temp`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `add_detalle_temp` (IN `codigo` INT, IN `cantidad` INT, IN `token_user` VARCHAR(50))  BEGIN
    
     DECLARE precio_actual decimal(10,2); 
  SELECT precio INTO precio_actual FROM productos WHERE codproducto = codigo;
        
        INSERT INTO detalle_temp(token_user,codproducto,cantidad,precio_venta) VALUES(token_user, codigo, cantidad, precio_actual);
        
        SELECT tmp.correlativo, tmp.codproducto,p.descripcion, tmp.cantidad, tmp.precio_venta FROM detalle_temp tmp 
        INNER JOIN productos p
        ON tmp.codproducto = p.codproducto
        WHERE tmp.token_user = token_user;
    END$$

DROP PROCEDURE IF EXISTS `anular_factura`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `anular_factura` (`no_factura` INT)  BEGIN
    	DECLARE existe_factura int;
        DECLARE registros int;
        DECLARE a int;
        
        DECLARE cod_producto varchar(11);
        DECLARE cant_producto int;
        DECLARE existencia_actual int;
        DECLARE nueva_existencia int;
        
        
        SET existe_factura = (SELECT COUNT(*) FROM factura WHERE nofactura = nofactura and estatus =1);
        
        IF existe_factura > 0 THEN
        
        	CREATE TEMPORARY TABLE tbl_tmp(
            id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                cod_prod varchar(11),
                cant_prod int);
                
              SET a = 1;
              
              SET registros = (SELECT COUNT(*) FROM detallefactura WHERE nofactura = no_factura);
              
              IF registros > 0 THEN
              
              INSERT INTO tbl_tmp(cod_prod,cant_prod) SELECT codproducto,cantidad FROM detallefactura WHERE nofactura = no_factura;
              
              WHILE a <= registros DO
              
              SELECT cod_prod,cant_prod INTO cod_producto,cant_producto FROM tbl_tmp WHERE id = a;
              SELECT stock INTO existencia_actual FROM productos WHERE codproducto = cod_producto;
              SET nueva_existencia = existencia_actual + cant_producto;
              UPDATE productos SET stock = nueva_existencia WHERE codproducto = cod_producto;
              SET a=a+1;
              
              END WHILE;
              
              UPDATE factura SET estatus = 2 WHERE nofactura = no_factura;
              DROP TABLE tbl_tmp;
              SELECT * FROM factura WHERE nofactura = no_factura;
              
              END IF;
        
        ELSE
        	SELECT 0 factura;
        END IF;
        
        

	END$$

DROP PROCEDURE IF EXISTS `dataDashboard`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `dataDashboard` ()  BEGIN
    	
        DECLARE usuarios int;
        DECLARE clientes int;
        DECLARE proveedores int;
        DECLARE productos int;
        DECLARE ventas int;
        
        SELECT COUNT(*) INTO usuarios FROM usuarios WHERE estatus !=10;
        SELECT COUNT(*) INTO clientes FROM clientes WHERE estatus !=10;
        SELECT COUNT(*) INTO proveedores FROM proveedores WHERE estatus !=10;
        SELECT COUNT(*) INTO productos FROM productos WHERE estatus !=10;
        SELECT COUNT(*) INTO ventas FROM factura WHERE fecha > CURDATE() AND estatus !=10;
        
        SELECT usuarios,clientes,proveedores,productos,ventas;
        
    
    END$$

DROP PROCEDURE IF EXISTS `del_detalle_temp`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `del_detalle_temp` (`id_detalle` INT, `token` VARCHAR(50))  BEGIN
         DELETE FROM detalle_temp WHERE correlativo = id_detalle;
         
         SELECT tmp.correlativo, tmp.codproducto,p.descripcion,tmp.cantidad,tmp.precio_venta FROM detalle_temp tmp
         INNER JOIN productos p
         ON tmp.codproducto = p.codproducto
         WHERE tmp.token_user = token;
         END$$

DROP PROCEDURE IF EXISTS `procesar_venta`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `procesar_venta` (IN `cod_usuario` INT, IN `cod_cliente` VARCHAR(11), IN `token` VARCHAR(50))  BEGIN
    
    	DECLARE factura INT;
        DECLARE registros INT;
        DECLARE total DECIMAL(10,2);
        
        DECLARE nueva_existencia int;
        DECLARE existencia_actual int;
        
        DECLARE tmp_cod_producto varchar(11);
        DECLARE tmp_cant_producto int;
        DECLARE a INT;
        SET a=1;
        
        CREATE TEMPORARY TABLE tbl_tmp_tokenuser(
        	id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            cod_prod varchar(11),
            cant_prod int);
            
            SET registros = (SELECT COUNT(*) FROM detalle_temp WHERE token_user = token);
            
            IF registros > 0 THEN
            INSERT INTO tbl_tmp_tokenuser(cod_prod,cant_prod) SELECT codproducto,cantidad FROM detalle_temp WHERE token_user = token;
            
            INSERT INTO factura(usuario,codcliente) VALUES(cod_usuario,cod_cliente);
            SET factura = LAST_INSERT_ID();
            
            INSERT INTO detallefactura(nofactura,codproducto,cantidad,precio_venta) SELECT (factura) as nofactura, codproducto,cantidad,
            precio_venta FROM detalle_temp WHERE token_user = token;
            
            WHILE a <= registros DO
            SELECT cod_prod,cant_prod INTO tmp_cod_producto,tmp_cant_producto FROM tbl_tmp_tokenuser WHERE id =a;
            SELECT stock INTO existencia_actual FROM productos WHERE codproducto = tmp_cod_producto;
            
            SET nueva_existencia = existencia_actual - tmp_cant_producto;
            UPDATE productos SET stock = nueva_existencia WHERE codproducto = tmp_cod_producto;
            
            SET a=a+1;
            
            END WHILE;
            
            SET total = (SELECT SUM(cantidad * precio_venta) FROM detalle_temp WHERE token_user = token);
            UPDATE factura SET totalfactura = total WHERE nofactura = factura;
            
            DELETE FROM detalle_temp WHERE token_user = token;
            TRUNCATE TABLE tbl_tmp_tokenuser;
            SELECT * FROM factura WHERE nofactura = factura;
            ELSE
            SELECT 0;
            END IF;
    
    END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `bitacora_clientes`
--

DROP TABLE IF EXISTS `bitacora_clientes`;
CREATE TABLE IF NOT EXISTS `bitacora_clientes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `registro` varchar(11) COLLATE utf8mb4_spanish_ci NOT NULL,
  `fechahora` datetime NOT NULL,
  `accion` varchar(30) COLLATE utf8mb4_spanish_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `bitacora_clientes`
--

INSERT INTO `bitacora_clientes` (`id`, `registro`, `fechahora`, `accion`) VALUES
(1, '8', '2021-12-31 20:08:01', 'ALTA_CLIENTE'),
(2, '7', '2021-12-31 20:08:55', 'MODIFICA_CLIENTE'),
(3, '6', '2021-12-31 20:09:32', 'ELIMINA_CLIENTE');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `bitacora_productos`
--

DROP TABLE IF EXISTS `bitacora_productos`;
CREATE TABLE IF NOT EXISTS `bitacora_productos` (
  `id` int(4) NOT NULL AUTO_INCREMENT,
  `registro` varchar(11) COLLATE utf8mb4_spanish_ci NOT NULL,
  `fechahora` datetime NOT NULL,
  `accion` varchar(30) COLLATE utf8mb4_spanish_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `bitacora_productos`
--

INSERT INTO `bitacora_productos` (`id`, `registro`, `fechahora`, `accion`) VALUES
(1, '8', '2021-12-31 20:25:08', 'ALTA_PRODUCTO'),
(2, '2', '2021-12-31 20:25:52', 'MODIFICA_PRODUCTO'),
(3, '8', '2021-12-31 20:26:21', 'BAJA_PRODUCTO'),
(4, '8', '2022-01-01 16:14:33', 'ALTA_PRODUCTO'),
(5, '8', '2022-01-01 16:18:33', 'MODIFICA_PRODUCTO'),
(6, '8', '2022-01-01 21:09:38', 'MODIFICA_PRODUCTO');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `bitacora_proveedores`
--

DROP TABLE IF EXISTS `bitacora_proveedores`;
CREATE TABLE IF NOT EXISTS `bitacora_proveedores` (
  `id` int(4) NOT NULL AUTO_INCREMENT,
  `registro` varchar(11) COLLATE utf8mb4_spanish_ci NOT NULL,
  `fechahora` datetime NOT NULL,
  `accion` varchar(30) COLLATE utf8mb4_spanish_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `bitacora_proveedores`
--

INSERT INTO `bitacora_proveedores` (`id`, `registro`, `fechahora`, `accion`) VALUES
(1, '6', '2021-12-31 20:16:33', 'ALTA_PROVEEDOR'),
(2, '2', '2021-12-31 20:17:23', 'MODIFICA_PROVEEDOR'),
(3, '6', '2021-12-31 20:18:11', 'BAJA_PROVEEDOR');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `bitacora_usuarios`
--

DROP TABLE IF EXISTS `bitacora_usuarios`;
CREATE TABLE IF NOT EXISTS `bitacora_usuarios` (
  `id` int(4) NOT NULL AUTO_INCREMENT,
  `registro` int(4) NOT NULL,
  `fechahora` datetime NOT NULL,
  `accion` varchar(30) COLLATE utf8mb4_spanish_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `bitacora_usuarios`
--

INSERT INTO `bitacora_usuarios` (`id`, `registro`, `fechahora`, `accion`) VALUES
(1, 16, '2021-12-31 19:51:42', 'ALTA_USUARIO'),
(2, 4, '2021-12-31 19:53:05', 'MODIFICA_USUARIO'),
(3, 5, '2021-12-31 19:53:42', 'ELIMINA_USUARIO');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `clientes`
--

DROP TABLE IF EXISTS `clientes`;
CREATE TABLE IF NOT EXISTS `clientes` (
  `cod_cliente` varchar(11) COLLATE utf8mb4_spanish_ci NOT NULL,
  `nombre` varchar(30) COLLATE utf8mb4_spanish_ci NOT NULL,
  `apellidos` varchar(30) COLLATE utf8mb4_spanish_ci NOT NULL,
  `telefono` varchar(10) COLLATE utf8mb4_spanish_ci NOT NULL,
  `direccion` varchar(100) COLLATE utf8mb4_spanish_ci NOT NULL,
  `dateadd` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `usuario_id` int(4) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`cod_cliente`),
  KEY `usuario_id` (`usuario_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `clientes`
--

INSERT INTO `clientes` (`cod_cliente`, `nombre`, `apellidos`, `telefono`, `direccion`, `dateadd`, `usuario_id`, `estatus`) VALUES
('1', 'Francisco', 'Salas', '6751239876', 'Calle Lomas Colonia El Salvador', '2021-12-21 19:33:23', 1, 1),
('2', 'Gustavo', 'Rocha', '6732134567', 'Calle Palomo Colonia El Salto', '2021-12-21 19:37:00', 6, 1),
('3', 'Rogelio', 'Villanueva', '6752319800', 'Calle Capital Colonia San Martin', '2021-12-21 22:33:51', 1, 1),
('4', 'Esteban', 'Toledo', '6784532199', 'Calle Pino Colonia Tempestad', '2021-12-21 22:34:42', 6, 1),
('5', 'Rosa Maria', 'Meraz', '6729870054', 'Calle Otto Colonia Pezca', '2021-12-21 22:35:39', 1, 1),
('7', 'Estela', 'Toledo', '6732314578', 'Calle 8 de Febrero Colonia La Hormiga', '2021-12-27 17:50:03', 1, 1),
('8', 'Esteban', 'Villalobos', '6542314576', 'Calle Loma Alta Colonia Suave', '2021-12-31 20:08:01', 1, 1);

--
-- Disparadores `clientes`
--
DROP TRIGGER IF EXISTS `alta_clientes`;
DELIMITER $$
CREATE TRIGGER `alta_clientes` AFTER INSERT ON `clientes` FOR EACH ROW insert into bitacora_clientes values(0,new.cod_cliente,now(),"ALTA_CLIENTE")
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `baja_clientes`;
DELIMITER $$
CREATE TRIGGER `baja_clientes` AFTER DELETE ON `clientes` FOR EACH ROW insert into bitacora_clientes values(0,old.cod_cliente,now(),"ELIMINA_CLIENTE")
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `modifica_clientes`;
DELIMITER $$
CREATE TRIGGER `modifica_clientes` AFTER UPDATE ON `clientes` FOR EACH ROW insert into bitacora_clientes values(0,old.cod_cliente,now(),"MODIFICA_CLIENTE")
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `configuracion`
--

DROP TABLE IF EXISTS `configuracion`;
CREATE TABLE IF NOT EXISTS `configuracion` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) COLLATE utf8mb4_spanish_ci NOT NULL,
  `razon_social` varchar(100) COLLATE utf8mb4_spanish_ci NOT NULL,
  `telefono` varchar(10) COLLATE utf8mb4_spanish_ci NOT NULL,
  `email` varchar(100) COLLATE utf8mb4_spanish_ci NOT NULL,
  `direccion` varchar(100) COLLATE utf8mb4_spanish_ci NOT NULL,
  `iva` decimal(10,2) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `configuracion`
--

INSERT INTO `configuracion` (`id`, `nombre`, `razon_social`, `telefono`, `email`, `direccion`, `iva`) VALUES
(1, 'Electronica RSZ', 'Electronica RSZ S.A.', '2185675432', 'info@electronicaRSZ.com', 'Santiago Papasquiaro, Dgo.', '16.00');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detallefactura`
--

DROP TABLE IF EXISTS `detallefactura`;
CREATE TABLE IF NOT EXISTS `detallefactura` (
  `correlativo` int(5) NOT NULL AUTO_INCREMENT,
  `nofactura` int(5) NOT NULL,
  `codproducto` varchar(11) COLLATE utf8mb4_spanish_ci NOT NULL,
  `cantidad` int(5) NOT NULL,
  `precio_venta` decimal(10,2) NOT NULL,
  PRIMARY KEY (`correlativo`),
  KEY `nofactura` (`nofactura`),
  KEY `codproducto` (`codproducto`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `detallefactura`
--

INSERT INTO `detallefactura` (`correlativo`, `nofactura`, `codproducto`, `cantidad`, `precio_venta`) VALUES
(1, 1, '1', 2, '410.00'),
(2, 1, '2', 1, '120.00'),
(3, 1, '3', 1, '1404.55'),
(4, 2, '1', 1, '410.00'),
(5, 3, '6', 1, '450.00'),
(6, 4, '2', 1, '120.00'),
(7, 4, '1', 2, '410.00'),
(9, 5, '6', 2, '450.00'),
(10, 5, '3', 1, '1404.55'),
(12, 6, '1', 5, '410.00'),
(13, 6, '2', 3, '120.00'),
(14, 7, '6', 1, '450.00'),
(15, 7, '2', 2, '120.00'),
(16, 8, '8', 10, '680.00');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_temp`
--

DROP TABLE IF EXISTS `detalle_temp`;
CREATE TABLE IF NOT EXISTS `detalle_temp` (
  `correlativo` int(5) NOT NULL AUTO_INCREMENT,
  `token_user` varchar(50) COLLATE utf8mb4_spanish_ci NOT NULL,
  `codproducto` varchar(11) COLLATE utf8mb4_spanish_ci NOT NULL,
  `cantidad` int(5) NOT NULL,
  `precio_venta` decimal(10,2) NOT NULL,
  PRIMARY KEY (`correlativo`),
  KEY `nofactura` (`token_user`),
  KEY `codproducto` (`codproducto`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `entradas`
--

DROP TABLE IF EXISTS `entradas`;
CREATE TABLE IF NOT EXISTS `entradas` (
  `correlativo` bigint(11) NOT NULL AUTO_INCREMENT,
  `codproducto` varchar(11) COLLATE utf8mb4_spanish_ci NOT NULL,
  `fecha` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `cantidad` int(5) NOT NULL,
  `precio` decimal(10,2) NOT NULL,
  `usuario_id` int(4) NOT NULL,
  PRIMARY KEY (`correlativo`),
  KEY `codproducto` (`codproducto`),
  KEY `usuario_id` (`usuario_id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `entradas`
--

INSERT INTO `entradas` (`correlativo`, `codproducto`, `fecha`, `cantidad`, `precio`, `usuario_id`) VALUES
(1, '1', '2021-12-22 17:53:25', 50, '430.00', 1),
(2, '2', '2021-12-22 20:09:00', 100, '150.00', 1),
(3, '3', '2021-12-22 20:23:13', 150, '1500.00', 1),
(5, '6', '2021-12-22 22:24:05', 250, '870.00', 1),
(6, '7', '2021-12-23 11:16:59', 100, '2350.00', 1),
(7, '2', '2021-12-23 19:21:59', 20, '120.00', 1),
(8, '2', '2021-12-23 22:45:18', 5, '120.00', 1),
(10, '1', '2021-12-23 23:23:35', 30, '350.00', 1),
(11, '3', '2021-12-23 23:25:56', 50, '1200.00', 1),
(12, '3', '2021-12-23 23:38:37', 20, '1200.00', 1),
(13, '8', '2022-01-01 16:14:33', 10, '680.00', 1),
(14, '8', '2022-01-01 21:09:38', 15, '650.00', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `factura`
--

DROP TABLE IF EXISTS `factura`;
CREATE TABLE IF NOT EXISTS `factura` (
  `nofactura` int(5) NOT NULL AUTO_INCREMENT,
  `fecha` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `usuario` int(4) NOT NULL,
  `codcliente` varchar(11) COLLATE utf8mb4_spanish_ci NOT NULL,
  `totalfactura` decimal(10,2) DEFAULT NULL,
  `estatus` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`nofactura`),
  KEY `usuario` (`usuario`),
  KEY `codcliente` (`codcliente`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `factura`
--

INSERT INTO `factura` (`nofactura`, `fecha`, `usuario`, `codcliente`, `totalfactura`, `estatus`) VALUES
(1, '2021-12-28 23:47:23', 1, '2', '2344.55', 1),
(2, '2021-12-28 23:49:27', 1, '1', '410.00', 2),
(3, '2021-12-29 01:09:53', 1, '4', '450.00', 1),
(4, '2021-12-29 14:24:01', 1, '1', '940.00', 1),
(5, '2021-12-29 15:52:50', 1, '2', '2304.55', 2),
(6, '2021-12-29 18:31:23', 1, '1', '2410.00', 2),
(7, '2021-12-30 16:03:28', 1, '5', '690.00', 2),
(8, '2022-01-01 16:18:32', 1, '7', '6800.00', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `productos`
--

DROP TABLE IF EXISTS `productos`;
CREATE TABLE IF NOT EXISTS `productos` (
  `codproducto` varchar(11) COLLATE utf8mb4_spanish_ci NOT NULL,
  `descripcion` varchar(100) COLLATE utf8mb4_spanish_ci NOT NULL,
  `proveedor` varchar(11) COLLATE utf8mb4_spanish_ci NOT NULL,
  `precio` decimal(10,2) NOT NULL,
  `stock` int(5) NOT NULL,
  `imagen` text COLLATE utf8mb4_spanish_ci NOT NULL,
  `date_add` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `usuario_id` int(4) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`codproducto`),
  KEY `proveedor` (`proveedor`),
  KEY `usuario_id` (`usuario_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `productos`
--

INSERT INTO `productos` (`codproducto`, `descripcion`, `proveedor`, `precio`, `stock`, `imagen`, `date_add`, `usuario_id`, `estatus`) VALUES
('1', 'Mouse USB ', '2', '410.00', 96, 'img_producto.png', '2021-12-22 17:53:25', 1, 1),
('2', 'USB Kingstone 32 GB', '1', '230.00', 123, 'img_producto.png', '2021-12-22 20:09:00', 1, 1),
('3', 'Disco Duro ADATA', '5', '1404.55', 219, 'img_producto.png', '2021-12-22 20:23:13', 1, 1),
('6', 'Memoria RAM 4GB', '3', '450.00', 249, 'img_producto.png', '2021-12-22 22:24:05', 1, 1),
('7', 'Tarjeta Madre Asus Prime', '5', '2333.33', 150, 'img_29aa293c8b2f40773ebbecb4e5ea1699.jpg', '2021-12-23 11:16:59', 1, 1),
('8', 'Teclado MecÃ¡nico', '5', '650.00', 15, 'img_producto.png', '2022-01-01 16:14:33', 1, 1);

--
-- Disparadores `productos`
--
DROP TRIGGER IF EXISTS `alta_productos`;
DELIMITER $$
CREATE TRIGGER `alta_productos` AFTER INSERT ON `productos` FOR EACH ROW insert into bitacora_productos values(0,new.codproducto,now(),"ALTA_PRODUCTO")
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `baja_productos`;
DELIMITER $$
CREATE TRIGGER `baja_productos` AFTER DELETE ON `productos` FOR EACH ROW insert into bitacora_productos values(0,old.codproducto,now(),"BAJA_PRODUCTO")
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `entradas_A_I`;
DELIMITER $$
CREATE TRIGGER `entradas_A_I` AFTER INSERT ON `productos` FOR EACH ROW BEGIN 
     INSERT INTO entradas(codproducto,cantidad,precio,usuario_id)
     VALUES(new.codproducto,new.stock,new.precio,new.usuario_id);
     END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `modifica_productos`;
DELIMITER $$
CREATE TRIGGER `modifica_productos` AFTER UPDATE ON `productos` FOR EACH ROW insert into bitacora_productos values(0,old.codproducto,now(),"MODIFICA_PRODUCTO")
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proveedores`
--

DROP TABLE IF EXISTS `proveedores`;
CREATE TABLE IF NOT EXISTS `proveedores` (
  `codproveedor` varchar(11) COLLATE utf8mb4_spanish_ci NOT NULL,
  `proveedor` varchar(100) COLLATE utf8mb4_spanish_ci NOT NULL,
  `telefono` varchar(10) COLLATE utf8mb4_spanish_ci NOT NULL,
  `correo` varchar(100) COLLATE utf8mb4_spanish_ci NOT NULL,
  `direccion` varchar(100) COLLATE utf8mb4_spanish_ci NOT NULL,
  `date_add` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `usuario_id` int(4) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`codproveedor`),
  KEY `usuario_id` (`usuario_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `proveedores`
--

INSERT INTO `proveedores` (`codproveedor`, `proveedor`, `telefono`, `correo`, `direccion`, `date_add`, `usuario_id`, `estatus`) VALUES
('1', 'Electronicos Platinum', '5564321234', 'electricplatin@electronicos.com', 'Calle Silvestre Colonia Rosales', '2021-12-22 14:44:55', 1, 1),
('2', 'Panasonic', '5146547898', 'panasonic@electronics.com', 'Avenida San Francisco', '2021-12-22 14:49:10', 1, 1),
('3', 'RadioShack', '5643219876', 'radioshack@services.com', 'Avenida Loma Linda', '2021-12-22 14:50:51', 2, 1),
('4', 'Samsung', '5642135678', 'samsung@corporative.com', 'Avenida Flor Dulce', '2021-12-22 14:51:24', 2, 1),
('5', 'Superelectricos', '5678763455', 'super@electronicos.com', 'Avenida 7 de Abril', '2021-12-22 14:53:11', 3, 1);

--
-- Disparadores `proveedores`
--
DROP TRIGGER IF EXISTS `alta_proveedores`;
DELIMITER $$
CREATE TRIGGER `alta_proveedores` AFTER INSERT ON `proveedores` FOR EACH ROW insert into bitacora_proveedores values(0,new.codproveedor,now(),"ALTA_PROVEEDOR")
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `baja_proveedores`;
DELIMITER $$
CREATE TRIGGER `baja_proveedores` AFTER DELETE ON `proveedores` FOR EACH ROW insert into bitacora_proveedores values(0,old.codproveedor,now(),"BAJA_PROVEEDOR")
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `modifica_proveedores`;
DELIMITER $$
CREATE TRIGGER `modifica_proveedores` AFTER UPDATE ON `proveedores` FOR EACH ROW insert into bitacora_proveedores values(0,old.codproveedor,now(),"MODIFICA_PROVEEDOR")
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `rol`
--

DROP TABLE IF EXISTS `rol`;
CREATE TABLE IF NOT EXISTS `rol` (
  `idrol` int(4) NOT NULL,
  `rol` varchar(20) COLLATE utf8mb4_spanish_ci NOT NULL,
  PRIMARY KEY (`idrol`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `rol`
--

INSERT INTO `rol` (`idrol`, `rol`) VALUES
(1, 'Administrador'),
(2, 'Vendedor');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

DROP TABLE IF EXISTS `usuarios`;
CREATE TABLE IF NOT EXISTS `usuarios` (
  `idusuario` int(4) NOT NULL,
  `nombre` varchar(50) COLLATE utf8mb4_spanish_ci NOT NULL,
  `apellidos` varchar(50) COLLATE utf8mb4_spanish_ci NOT NULL,
  `correo` varchar(100) COLLATE utf8mb4_spanish_ci NOT NULL,
  `usuario` varchar(20) COLLATE utf8mb4_spanish_ci NOT NULL,
  `password` varchar(100) COLLATE utf8mb4_spanish_ci NOT NULL,
  `rol` int(4) NOT NULL,
  `estatus` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`idusuario`),
  KEY `rol` (`rol`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`idusuario`, `nombre`, `apellidos`, `correo`, `usuario`, `password`, `rol`, `estatus`) VALUES
(1, 'Jesus', 'Saravia Diaz', 'lgsus998@gmail.com', 'lgsus', 'd24a21846d71dfa3ecbc24629c2d780d', 1, 1),
(2, 'Eduardo', 'Ramos', 'lalo678@gmail.com', 'lalo', '6d6354ece40846bf7fca65dfabd5d9d4', 1, 1),
(3, 'Reynoldo', 'Zavala', 'RenoldZ@gmail.com', 'reynold', 'd28b4da9d1eefe3faf22ce9d01c0b48c', 1, 1),
(4, 'Cecilia Maria', 'Sanchez Perez', 'ceci12@gmail.com', 'ceci123', 'd93591bdf7860e1e4ee2fca799911215', 2, 1),
(6, 'Mario', 'Gonzalez Blanco', 'MarioG@gmail.com', 'mario', 'de2f15d014d40b93578d255e6221fd60', 2, 1),
(7, 'Angelica', 'Cervantes', 'angelica@gmail.com', 'angelica', '5903d9e9a8884c8c04ad16559446735a', 2, 1),
(8, 'Jose', 'Fernandez', 'josef@gmail.com', 'jose', '662eaa47199461d01a623884080934ab', 1, 1),
(9, 'Leticia', 'Carrera', 'Leticia@gmail.com', 'leticia', 'dd42f170a60748804f532ab00397e9af', 2, 1),
(10, 'Astrid', 'Saravia', 'astrid@gmail.com', 'astrid', '8ce5b08166e3a739b438bb5f541c18dc', 1, 1),
(11, 'Cristina', 'Diaz Arellano', 'Cristy@gmail.com', 'cristy', '0c74ac34d6652b2da30488d4f38496d8', 1, 1),
(12, 'Alfredo', 'Arellano', 'freddy@gmail.com', 'freddy', '5c2bf15004e661d7b7c9394617143d07', 2, 1),
(13, 'Maria', 'Zepeda', 'MariaZ@gmail.com', 'maria', '263bce650e68ab4e23f28263760b9fa5', 2, 1),
(14, 'Ramiro', 'Villarreal', 'RamVilla@gmail.com', 'ramiro', '49bbccc812370520878c7f343d48900b', 1, 1),
(15, 'Guillermo', 'Lopez', 'guillermo@gmail.com', 'guillermo', 'd7ed8e65834e0f58fa7c43f332e64cfe', 2, 1),
(16, 'Rigoberto', 'Martinez Perez', 'Rigo@gmail.com', 'rigoberto', 'b94343f1c4a54effc1fb66d3472d6d1c', 2, 1);

--
-- Disparadores `usuarios`
--
DROP TRIGGER IF EXISTS `alta_usuarios`;
DELIMITER $$
CREATE TRIGGER `alta_usuarios` AFTER INSERT ON `usuarios` FOR EACH ROW insert into bitacora_usuarios values(0,new.idusuario,now(),"ALTA_USUARIO")
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `baja_usuarios`;
DELIMITER $$
CREATE TRIGGER `baja_usuarios` AFTER DELETE ON `usuarios` FOR EACH ROW insert into bitacora_usuarios values(0,old.idusuario,now(),"ELIMINA_USUARIO")
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `modifica_usuarios`;
DELIMITER $$
CREATE TRIGGER `modifica_usuarios` AFTER UPDATE ON `usuarios` FOR EACH ROW insert into bitacora_usuarios values(0,old.idusuario,now(),"MODIFICA_USUARIO")
$$
DELIMITER ;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `clientes`
--
ALTER TABLE `clientes`
  ADD CONSTRAINT `clientes_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`idusuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detallefactura`
--
ALTER TABLE `detallefactura`
  ADD CONSTRAINT `detallefactura_ibfk_2` FOREIGN KEY (`codproducto`) REFERENCES `productos` (`codproducto`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `detallefactura_ibfk_3` FOREIGN KEY (`nofactura`) REFERENCES `factura` (`nofactura`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `detalle_temp`
--
ALTER TABLE `detalle_temp`
  ADD CONSTRAINT `detalle_temp_ibfk_2` FOREIGN KEY (`codproducto`) REFERENCES `productos` (`codproducto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `entradas`
--
ALTER TABLE `entradas`
  ADD CONSTRAINT `entradas_ibfk_1` FOREIGN KEY (`codproducto`) REFERENCES `productos` (`codproducto`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `entradas_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`idusuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `factura`
--
ALTER TABLE `factura`
  ADD CONSTRAINT `factura_ibfk_1` FOREIGN KEY (`codcliente`) REFERENCES `clientes` (`cod_cliente`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `factura_ibfk_2` FOREIGN KEY (`usuario`) REFERENCES `usuarios` (`idusuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `productos`
--
ALTER TABLE `productos`
  ADD CONSTRAINT `productos_ibfk_1` FOREIGN KEY (`proveedor`) REFERENCES `proveedores` (`codproveedor`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `productos_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`idusuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `proveedores`
--
ALTER TABLE `proveedores`
  ADD CONSTRAINT `proveedores_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`idusuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD CONSTRAINT `usuarios_ibfk_1` FOREIGN KEY (`rol`) REFERENCES `rol` (`idrol`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
