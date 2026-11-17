package com.optativa.backend;

import com.optativa.backend.dto.request.ProductoCrearRequest;
import com.optativa.backend.service.HuellaAlta;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

class HuellaAltaTest {
    private final HuellaAlta huella = new HuellaAlta();
    @Test void normalizaPrecioYEspaciosSinDependerDeJson() {
        UUID uuid = UUID.randomUUID();
        var a = new ProductoCrearRequest(uuid, " Taza ", " Cerámica ", new BigDecimal("35"), true);
        var b = new ProductoCrearRequest(uuid, "Taza", "Cerámica", new BigDecimal("35.00"), true);
        assertEquals(huella.calcular(a, new byte[]{1, 2}), huella.calcular(b, new byte[]{1, 2}));
        assertNotEquals(huella.calcular(a, new byte[]{1, 2}), huella.calcular(b, new byte[]{1, 3}));
    }
    @Test void separaCamposYEstadoSinAmbiguedad() {
        UUID uuid = UUID.randomUUID();
        var a = new ProductoCrearRequest(uuid, "ab", "c", BigDecimal.ZERO, true);
        var b = new ProductoCrearRequest(uuid, "a", "bc", BigDecimal.ZERO, true);
        var c = new ProductoCrearRequest(uuid, "ab", "c", BigDecimal.ZERO, false);
        assertNotEquals(huella.calcular(a, new byte[0]), huella.calcular(b, new byte[0]));
        assertNotEquals(huella.calcular(a, new byte[0]), huella.calcular(c, new byte[0]));
        assertTrue(huella.calcular(a, new byte[0]).matches("[0-9a-f]{64}"));
    }
}
