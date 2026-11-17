package com.optativa.backend.service;

import com.optativa.backend.dto.request.*;
import com.optativa.backend.dto.response.*;
import org.springframework.web.multipart.MultipartFile;

public interface ProductoService {
    record Alta(ProductoResponse producto, boolean creado) {}
    Alta crear(ProductoCrearRequest datos, MultipartFile foto);
    ProductoResponse editar(Long id, ProductoEditarRequest datos, MultipartFile foto);
    PaginaResponse<ProductoResponse> propios(int page, int size);
}
