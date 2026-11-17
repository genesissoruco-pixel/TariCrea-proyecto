package com.optativa.backend.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.util.Date;

@Component
public class JwtService {
    private final SecretKey clave;
    private final String emisor;
    private final Duration vigencia;
    public JwtService(@Value("${app.jwt.secret}") String secreto,
                      @Value("${app.jwt.issuer}") String emisor,
                      @Value("${app.jwt.expiration}") Duration vigencia) {
        this.clave = Keys.hmacShaKeyFor(secreto.getBytes(StandardCharsets.UTF_8));
        this.emisor = emisor;
        if (vigencia.isNegative() || vigencia.isZero()) throw new IllegalArgumentException("Vigencia JWT inválida");
        this.vigencia = vigencia;
    }
    public String emitir(Long usuarioId) {
        Instant ahora = Instant.now();
        return Jwts.builder().issuer(emisor).subject(usuarioId.toString()).issuedAt(Date.from(ahora))
                .expiration(Date.from(ahora.plus(vigencia))).signWith(clave).compact();
    }
    public Long validar(String token) {
        Claims claims = Jwts.parser().verifyWith(clave).requireIssuer(emisor).build().parseSignedClaims(token).getPayload();
        if (claims.getExpiration() == null || claims.getIssuedAt() == null) throw new JwtException("Token incompleto");
        return Long.valueOf(claims.getSubject());
    }
}
