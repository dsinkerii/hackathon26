package com.playground.security.repository;

import com.playground.security.entity.AdminRole;
import com.playground.security.entity.AdminUser;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AdminUserRepository extends JpaRepository<AdminUser, String> {
    Optional<AdminUser> findByUsernameIgnoreCase(String username);
    boolean existsByUsernameIgnoreCase(String username);
    long countByRoleAndEnabledTrue(AdminRole role);
    List<AdminUser> findAllByOrderByCreatedAtAsc();
}
