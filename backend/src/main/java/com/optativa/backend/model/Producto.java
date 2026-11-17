package com.optativa.backend.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "producto", uniqueConstraints = @UniqueConstraint(name = "uq_producto_cliente_uuid", columnNames = {"emprendimiento_id", "cliente_uuid"}))
@Getter @Setter
public class Producto {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "emprendimiento_id", nullable = false, updatable = false)
    private Emprendimiento emprendimiento;
    @Column(name = "cliente_uuid", nullable = false, updatable = false)
    private UUID clienteUuid;
    @Column(nullable = false, length = 150)
    private String nombre;
    @Column(nullable = false, columnDefinition = "text")
    private String descripcion;
    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal precio;
    @Column(name = "foto_producto_ruta", nullable = false, length = 500)
    private String fotoProductoRuta;
    @Column(nullable = false)
    private boolean publicado = true;
    @Column(name = "alta_hash", nullable = false, length = 64, updatable = false)
    private String altaHash;
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
