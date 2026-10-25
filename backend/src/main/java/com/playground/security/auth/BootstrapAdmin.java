package com.playground.security.auth;

import com.playground.security.config.AppProperties;
import com.playground.security.entity.AdminRole;
import com.playground.security.entity.AdminUser;
import com.playground.security.repository.AdminUserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class BootstrapAdmin {
    private static final Logger log = LoggerFactory.getLogger(BootstrapAdmin.class);

    @Bean
    ApplicationRunner createInitialAdmin(
            AppProperties properties,
            AdminUserRepository users,
            PasswordEncoder passwordEncoder) {
        return args -> {
            String username = properties.security().initialAdminUsername();
            String password = properties.security().initialAdminPassword();
            boolean hasUsername = username != null && !username.isBlank();
            boolean hasPassword = password != null && !password.isBlank();
            if (hasUsername != hasPassword) {
                throw new IllegalStateException(
                        "Set both INITIAL_ADMIN_USERNAME and INITIAL_ADMIN_PASSWORD.");
            }
            if (!hasUsername) {
                log.warn("No bootstrap administrator configured; set initial admin credentials to enable first login.");
                return;
            }
            if (password.length() < 12) {
                throw new IllegalStateException("INITIAL_ADMIN_PASSWORD must contain at least 12 characters.");
            }
            if (!users.existsByUsernameIgnoreCase(username)) {
                users.save(new AdminUser(
                        java.util.UUID.randomUUID().toString(),
                        username.trim(),
                        passwordEncoder.encode(password),
                        AdminRole.ADMIN));
                log.info("Created bootstrap administrator '{}'.", username.trim());
            }
        };
    }
}
