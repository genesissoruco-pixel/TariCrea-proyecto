package com.optativa.backend.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.time.Instant;

@Entity @Table(name = "usuario") @Getter @Setter
public class Usuario {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, length = 120)
    private String nombre;
    @Column(name = "apellido_paterno", length = 100)
    private String apellidoPaterno;
    @Column(name = "apellido_materno", length = 100)
    private String apellidoMaterno;
    @Column(length = 20)
    private String telefono;
    @Column(nullable = false, length = 254)
    private String correo;
    @Column(name = "contrasena_hash", nullable = false, length = 255)
    private String contrasenaHash;
    @Column(nullable = false)
    private boolean activo = true;
    @Column(name = "creado_en", nullable = false, updatable = false)
    private Instant creadoEn;
    @Column(name = "actualizado_en", nullable = false)
    private Instant actualizadoEn;

    @PrePersist void crearFechas() {
        creadoEn = Instant.now();
        actualizadoEn = creadoEn;
    }
    @PreUpdate void actualizarFecha() { actualizadoEn = Instant.now(); }
}
