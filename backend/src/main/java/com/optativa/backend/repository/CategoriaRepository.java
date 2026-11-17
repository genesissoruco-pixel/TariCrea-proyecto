package com.optativa.backend.repository;

import com.optativa.backend.model.Categoria;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface CategoriaRepository extends JpaRepository<Categoria, Long> {
    List<Categoria> findByActivaTrueOrderByNombreAsc();
}
