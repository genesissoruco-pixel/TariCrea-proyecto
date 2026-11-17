package com.optativa.backend.controller;

import com.optativa.backend.dto.request.EmprendimientoRequest;
import com.optativa.backend.dto.response.ApiResponse;
import com.optativa.backend.service.EmprendimientoService;
import jakarta.validation.Valid;
import jakarta.validation.groups.Default;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController @RequestMapping("/api/emprendimientos") @RequiredArgsConstructor
public class EmprendimientoController {
    private final EmprendimientoService emprendimientos;
    @GetMapping("/mio")
    public ApiResponse<?> mio() { return ApiResponse.ok("Mi emprendimiento.", emprendimientos.mio()); }
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> crear(
            @Validated({Default.class, EmprendimientoRequest.Alta.class}) @RequestPart("datos") EmprendimientoRequest datos,
            @RequestPart("foto") MultipartFile foto) {
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok("Emprendimiento registrado.", emprendimientos.crear(datos, foto)));
    }
    @PutMapping(value = "/mio", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<?> editar(@Valid @RequestPart("datos") EmprendimientoRequest datos,
                                @RequestPart(value = "foto", required = false) MultipartFile foto) {
        return ApiResponse.ok("Emprendimiento actualizado.", emprendimientos.editar(datos, foto));
    }
}
