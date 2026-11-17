package com.optativa.backend.dto.response;

import org.springframework.data.domain.Page;
import java.util.List;

public record PaginaResponse<T>(List<T> items, int page, int size, long total, int totalPages) {
    public static <T> PaginaResponse<T> de(Page<T> pagina) {
        return new PaginaResponse<>(pagina.getContent(), pagina.getNumber(), pagina.getSize(), pagina.getTotalElements(), pagina.getTotalPages());
    }
}
