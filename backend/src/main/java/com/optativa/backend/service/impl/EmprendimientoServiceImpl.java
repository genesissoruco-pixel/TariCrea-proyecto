package com.optativa.backend.service.impl;

import com.optativa.backend.dto.request.EmprendimientoRequest;
import com.optativa.backend.dto.response.EmprendimientoResponse;
import com.optativa.backend.exception.ApiException;
import com.optativa.backend.model.*;
import com.optativa.backend.repository.*;
import com.optativa.backend.security.UsuarioActual;
import com.optativa.backend.service.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service @RequiredArgsConstructor
public class EmprendimientoServiceImpl implements EmprendimientoService {
    private final UsuarioActual actual;
    private final UsuarioRepository usuarios;
    private final EmprendimientoRepository emprendimientos;
    private final CategoriaRepository categorias;
    private final ImagenService imagenes;

    @Override @Transactional(readOnly = true)
    public EmprendimientoResponse mio() {
        return EmprendimientoResponse.de(emprendimientos.findByUsuarioId(actual.id())
                .orElseThrow(() -> ApiException.noEncontrado("Aún no tiene un emprendimiento.")));
    }
    @Override @Transactional
    public EmprendimientoResponse crear(EmprendimientoRequest datos, MultipartFile foto) {
        Usuario usuario = usuarios.bloquear(actual.id()).filter(Usuario::isActivo)
                .orElseThrow(() -> new BadCredentialsException("Cuenta inválida"));
        if (emprendimientos.findByUsuarioId(usuario.getId()).isPresent())
            throw ApiException.conflicto("Cada cuenta puede registrar un solo emprendimiento.");
        Emprendimiento emprendimiento = new Emprendimiento();
        emprendimiento.setUsuario(usuario);
        aplicar(emprendimiento, datos);
        emprendimiento.setFotoLugarRuta(imagenes.guardar("emprendimientos", imagenes.validar(foto), null));
        return EmprendimientoResponse.de(emprendimientos.saveAndFlush(emprendimiento));
    }
    @Override @Transactional
    public EmprendimientoResponse editar(EmprendimientoRequest datos, MultipartFile foto) {
        Emprendimiento emprendimiento = emprendimientos.bloquearPropio(actual.id())
                .orElseThrow(() -> ApiException.noEncontrado("Aún no tiene un emprendimiento."));
        aplicar(emprendimiento, datos);
        if (foto != null) emprendimiento.setFotoLugarRuta(imagenes.guardar("emprendimientos", imagenes.validar(foto), emprendimiento.getFotoLugarRuta()));
        return EmprendimientoResponse.de(emprendimientos.saveAndFlush(emprendimiento));
    }
    private void aplicar(Emprendimiento e, EmprendimientoRequest datos) {
        Categoria categoria = categorias.findById(datos.categoriaId())
                .filter(Categoria::isActiva).orElseThrow(() -> ApiException.invalido("La categoría no existe o está inactiva."));
        e.setCategoria(categoria);
        e.setNombre(datos.nombre().strip());
        e.setDescripcion(datos.descripcion().strip());
        e.setTelefono(datos.telefono() == null || datos.telefono().isBlank() ? null : datos.telefono().strip());
        if (datos.direccionReferencia() != null) e.setDireccionReferencia(datos.direccionReferencia().strip());
        if (datos.horarioAtencion() != null) e.setHorarioAtencion(datos.horarioAtencion().strip());
        e.setLatitud(datos.latitud());
        e.setLongitud(datos.longitud());
        e.setPublicado(datos.publicado());
    }
}
