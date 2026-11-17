package com.optativa.backend.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.Instant;

@Entity @Table(name = "emprendimiento") @Getter @Setter
public class Emprendimiento {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "usuario_id", nullable = false, unique = true)
    private Usuario usuario;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "categoria_id", nullable = false)
    private Categoria categoria;
    @Column(nullable = false, length = 150)
    private String nombre;
    @Column(nullable = false, columnDefinition = "text")
    private String descripcion;
    @Column(length = 30)
    private String telefono;
    @Column(name = "direccion_referencia", length = 255)
    private String direccionReferencia;
    @Column(name = "horario_atencion", length = 255)
    private String horarioAtencion;
    @Column(nullable = false, precision = 10, scale = 7)
    private BigDecimal latitud;
    @Column(nullable = false, precision = 10, scale = 7)
    private BigDecimal longitud;
    @Column(name = "foto_lugar_ruta", nullable = false, length = 500)
    private String fotoLugarRuta;
    @Column(nullable = false)
    private boolean publicado = true;
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
