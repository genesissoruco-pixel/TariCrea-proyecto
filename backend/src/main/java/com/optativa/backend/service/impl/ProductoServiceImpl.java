package com.optativa.backend.service.impl;

import com.optativa.backend.dto.request.*;
import com.optativa.backend.dto.response.*;
import com.optativa.backend.exception.ApiException;
import com.optativa.backend.model.*;
import com.optativa.backend.repository.*;
import com.optativa.backend.security.UsuarioActual;
import com.optativa.backend.service.*;
import com.optativa.backend.validation.Paginacion;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import java.math.RoundingMode;

@Service @RequiredArgsConstructor
public class ProductoServiceImpl implements ProductoService {
    private final UsuarioActual actual;
    private final EmprendimientoRepository emprendimientos;
    private final ProductoRepository productos;
    private final ImagenService imagenes;
    private final HuellaAlta huella;

    @Override @Transactional
    public Alta crear(ProductoCrearRequest datos, MultipartFile foto) {
        // Todas las altas y ediciones de un negocio se serializan mediante una fila persistente.
        // La restricción UNIQUE conserva la integridad frente a otros clientes de la BD.
        Emprendimiento emprendimiento = emprendimientos.bloquearPropio(actual.id())
                .orElseThrow(() -> ApiException.noEncontrado("Registre primero su emprendimiento."));
        var imagen = imagenes.validar(foto);
        String hash = huella.calcular(datos, imagen.original());
        var existente = productos.findByEmprendimientoIdAndClienteUuid(emprendimiento.getId(), datos.clienteUuid());
        if (existente.isPresent()) {
            Producto producto = existente.get();
            if (!producto.getAltaHash().equals(hash)) throw ApiException.conflicto("El UUID ya se utilizó con otros datos o fotografía.");
            return new Alta(ProductoResponse.de(producto), false);
        }
        Producto producto = new Producto();
        producto.setEmprendimiento(emprendimiento);
        producto.setClienteUuid(datos.clienteUuid());
        producto.setAltaHash(hash);
        producto.setNombre(datos.nombre().strip());
        producto.setDescripcion(datos.descripcion().strip());
        producto.setPrecio(datos.precio().setScale(2, RoundingMode.UNNECESSARY));
        producto.setPublicado(datos.publicado());
        producto.setFotoProductoRuta(imagenes.guardar("productos", imagen, null));
        return new Alta(ProductoResponse.de(productos.saveAndFlush(producto)), true);
    }
    @Override @Transactional
    public ProductoResponse editar(Long id, ProductoEditarRequest datos, MultipartFile foto) {
        Emprendimiento propio = emprendimientos.bloquearPropio(actual.id())
                .orElseThrow(() -> ApiException.noEncontrado("Producto no encontrado."));
        Producto producto = productos.findByIdAndEmprendimientoId(id, propio.getId())
                .orElseThrow(() -> ApiException.noEncontrado("Producto no encontrado."));
        producto.setNombre(datos.nombre().strip());
        producto.setDescripcion(datos.descripcion().strip());
        producto.setPrecio(datos.precio().setScale(2, RoundingMode.UNNECESSARY));
        producto.setPublicado(datos.publicado());
        if (foto != null) producto.setFotoProductoRuta(imagenes.guardar("productos", imagenes.validar(foto), producto.getFotoProductoRuta()));
        return ProductoResponse.de(productos.saveAndFlush(producto));
    }
    @Override @Transactional(readOnly = true)
    public PaginaResponse<ProductoResponse> propios(int page, int size) {
        var pagina = Paginacion.de(page, size);
        var propio = emprendimientos.findByUsuarioId(actual.id())
                .orElseThrow(() -> ApiException.noEncontrado("Registre primero su emprendimiento."));
        return PaginaResponse.de(productos.findByEmprendimientoId(propio.getId(), pagina).map(ProductoResponse::de));
    }
}
