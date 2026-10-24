package com.playground.security.repository;

import com.playground.security.entity.Person;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PersonRepository extends JpaRepository<Person, String> {
    List<Person> findAllByOrderByLastSeenAtDesc();
}
