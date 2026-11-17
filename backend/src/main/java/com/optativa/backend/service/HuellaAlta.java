package com.optativa.backend.service;

import com.optativa.backend.dto.request.ProductoCrearRequest;
import org.springframework.stereotype.Component;
import java.io.*;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.HexFormat;

@Component
public class HuellaAlta {
    public String calcular(ProductoCrearRequest datos, byte[] foto) {
        try {
            var digest = MessageDigest.getInstance("SHA-256");
            try (var salida = new DataOutputStream(new DigestOutputStream(OutputStream.nullOutputStream(), digest))) {
                texto(salida, "optativa-alta-v1");
                texto(salida, datos.clienteUuid().toString());
                texto(salida, datos.nombre().strip());
                texto(salida, datos.descripcion().strip());
                texto(salida, datos.precio().setScale(2, RoundingMode.UNNECESSARY).toPlainString());
                salida.writeBoolean(datos.publicado());
                salida.writeInt(foto.length);
                salida.write(foto);
            }
            return HexFormat.of().formatHex(digest.digest());
        } catch (IOException | NoSuchAlgorithmException ex) {
            throw new IllegalStateException("No se pudo calcular la huella de alta", ex);
        }
    }
    private void texto(DataOutputStream salida, String texto) throws IOException {
        byte[] bytes = texto.getBytes(StandardCharsets.UTF_8);
        salida.writeInt(bytes.length);
        salida.write(bytes);
    }
}
