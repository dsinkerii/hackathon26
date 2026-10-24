package com.playground.security.auth;

import com.playground.security.common.ApiException;
import com.playground.security.config.AppProperties;
import com.playground.security.entity.AdminRole;
import com.playground.security.entity.AdminUser;
import com.playground.security.repository.AdminUserRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@PreAuthorize("hasRole('ADMIN')")
@RequestMapping("/api/v1/users")
public class AdminUserController {
    private final AdminUserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final AppProperties properties;

    public AdminUserController(
            AdminUserRepository users,
            PasswordEncoder passwordEncoder,
            AppProperties properties) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.properties = properties;
    }

    /** Основная (bootstrap) учётная запись — под защитой от удаления. */
    public static boolean isPrimary(AdminUser user, AppProperties properties) {
        String initial = properties.security().initialAdminUsername();
        return initial != null && !initial.isBlank()
                && user.getRole() == AdminRole.ADMIN
                && user.getUsername().equalsIgnoreCase(initial.trim());
    }

    @GetMapping
    public List<UserResponse> list() {
        return users.findAllByOrderByCreatedAtAsc().stream()
                .map(user -> UserResponse.from(user, isPrimary(user, properties)))
                .toList();
    }

    @PostMapping
    public UserResponse create(@Valid @RequestBody CreateUserRequest request) {
        String username = request.username().trim();
        if (users.existsByUsernameIgnoreCase(username)) {
            throw new ApiException(HttpStatus.CONFLICT, "USERNAME_TAKEN", "Username is already in use.");
        }
        AdminUser user = users.save(new AdminUser(
                UUID.randomUUID().toString(),
                username,
                passwordEncoder.encode(request.password()),
                request.role()));
        return UserResponse.from(user, isPrimary(user, properties));
    }

    @PatchMapping("/{id}/enabled")
    public UserResponse setEnabled(
            @PathVariable String id,
            @Valid @RequestBody EnabledRequest request,
            @AuthenticationPrincipal Jwt principal) {
        AdminUser user = users.findById(id)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Account was not found."));
        if (!request.enabled() && user.getUsername().equalsIgnoreCase(
                principal.getClaimAsString("username"))) {
            throw new ApiException(HttpStatus.CONFLICT, "CANNOT_DISABLE_SELF",
                    "You cannot disable your own account.");
        }
        if (!request.enabled() && user.getRole() == AdminRole.ADMIN
                && users.countByRoleAndEnabledTrue(AdminRole.ADMIN) <= 1) {
            throw new ApiException(HttpStatus.CONFLICT, "LAST_ADMIN",
                    "The last enabled administrator cannot be disabled.");
        }
        user.setEnabled(request.enabled());
        return UserResponse.from(users.save(user), isPrimary(user, properties));
    }

    /** Удаление учётной записи: запрещено для основной и собственной. */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(
            @PathVariable String id,
            @AuthenticationPrincipal Jwt principal) {
        AdminUser user = users.findById(id)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Account was not found."));
        if (isPrimary(user, properties)) {
            throw new ApiException(HttpStatus.CONFLICT, "CANNOT_DELETE_PRIMARY",
                    "The primary administrator cannot be deleted.");
        }
        if (user.getUsername().equalsIgnoreCase(principal.getClaimAsString("username"))) {
            throw new ApiException(HttpStatus.CONFLICT, "CANNOT_DELETE_SELF",
                    "You cannot delete your own account.");
        }
        if (user.getRole() == AdminRole.ADMIN && user.isEnabled()
                && users.countByRoleAndEnabledTrue(AdminRole.ADMIN) <= 1) {
            throw new ApiException(HttpStatus.CONFLICT, "LAST_ADMIN",
                    "The last enabled administrator cannot be deleted.");
        }
        users.delete(user);
        return ResponseEntity.noContent().build();
    }

    public record CreateUserRequest(
            @NotBlank @Size(max = 80)
            @Pattern(regexp = "[A-Za-z0-9._-]+", message = "must contain only letters, digits, '.', '_' or '-'")
            String username,
            @NotBlank @Size(min = 12, max = 200) String password,
            AdminRole role) {
        public CreateUserRequest {
            if (role == null) {
                role = AdminRole.OPERATOR;
            }
        }
    }

    public record EnabledRequest(boolean enabled) {}

    public record UserResponse(
            String id, String username, String role, boolean enabled,
            boolean primary, java.time.OffsetDateTime createdAt) {
        static UserResponse from(AdminUser user, boolean primary) {
            return new UserResponse(user.getId(), user.getUsername(), user.getRole().name(),
                    user.isEnabled(), primary, user.getCreatedAt());
        }
    }
}
