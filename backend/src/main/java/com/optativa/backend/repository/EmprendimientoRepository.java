package com.optativa.backend.repository;

import com.optativa.backend.model.Emprendimiento;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.*;
import jakarta.persistence.LockModeType;
import java.util.Optional;

public interface EmprendimientoRepository extends JpaRepository<Emprendimiento, Long> {
    Optional<Emprendimiento> findByUsuarioId(Long usuarioId);
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select e from Emprendimiento e where e.usuario.id = :usuarioId")
    Optional<Emprendimiento> bloquearPropio(Long usuarioId);
    Optional<Emprendimiento> findByIdAndPublicadoTrue(Long id);
    boolean existsByFotoLugarRutaAndPublicadoTrue(String fotoLugarRuta);
    boolean existsByFotoLugarRutaAndUsuarioId(String fotoLugarRuta, Long usuarioId);
    @Query("select e from Emprendimiento e where e.publicado = true and (:categoriaId is null or e.categoria.id = :categoriaId) and lower(e.nombre) like :nombre escape '!'")
    Page<Emprendimiento> buscarPublicados(String nombre, Long categoriaId, Pageable pagina);
}
