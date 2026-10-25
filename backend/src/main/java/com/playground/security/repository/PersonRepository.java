package com.playground.security.repository;

import com.playground.security.entity.Person;
import com.playground.security.entity.PersonStatus;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PersonRepository extends JpaRepository<Person, String> {
    List<Person> findAllByOrderByLastSeenAtDesc();

    List<Person> findAllByStatusOrderByLastSeenAtDesc(PersonStatus status);
}
