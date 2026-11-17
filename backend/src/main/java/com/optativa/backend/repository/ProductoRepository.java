package com.optativa.backend.repository;

import com.optativa.backend.model.Producto;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
import java.util.UUID;

public interface ProductoRepository extends JpaRepository<Producto, Long> {
    Optional<Producto> findByEmprendimientoIdAndClienteUuid(Long emprendimientoId, UUID clienteUuid);
    boolean existsByFotoProductoRutaAndPublicadoTrueAndEmprendimientoPublicadoTrue(String fotoProductoRuta);
    boolean existsByFotoProductoRutaAndEmprendimientoUsuarioId(String fotoProductoRuta, Long usuarioId);
    Optional<Producto> findByIdAndEmprendimientoId(Long id, Long emprendimientoId);
    Page<Producto> findByEmprendimientoId(Long emprendimientoId, Pageable pagina);
    Page<Producto> findByEmprendimientoIdAndPublicadoTrueAndEmprendimientoPublicadoTrue(Long emprendimientoId, Pageable pagina);
}
