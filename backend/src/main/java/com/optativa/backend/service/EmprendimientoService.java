package com.optativa.backend.service;

import com.optativa.backend.dto.request.EmprendimientoRequest;
import com.optativa.backend.dto.response.EmprendimientoResponse;
import org.springframework.web.multipart.MultipartFile;

public interface EmprendimientoService {
    EmprendimientoResponse mio();
    EmprendimientoResponse crear(EmprendimientoRequest datos, MultipartFile foto);
    EmprendimientoResponse editar(EmprendimientoRequest datos, MultipartFile foto);
}
