package com.optativa.backend.validation;

import com.optativa.backend.exception.ApiException;
import org.springframework.data.domain.*;

public final class Paginacion {
    private Paginacion() {}
    public static Pageable de(int page, int size) {
        if (page < 0 || size < 1 || size > 50 || (long) page * size > Integer.MAX_VALUE)
            throw ApiException.invalido("Use page >= 0 y size entre 1 y 50.");
        return PageRequest.of(page, size, Sort.by("id"));
    }
}
