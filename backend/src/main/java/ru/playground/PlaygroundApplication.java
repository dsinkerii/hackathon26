package ru.playground;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

/**
 * Единое приложение: каркас ru.playground (новые модули) + MVP-слои
 * com.playground.security (ingest, SSE-алерты, журнал, демо-сидер),
 * перенесённые из ветки верификации MVP.
 */
@SpringBootApplication(scanBasePackages = {"ru.playground", "com.playground.security"})
@ConfigurationPropertiesScan({"ru.playground", "com.playground.security"})
@EnableJpaRepositories({"ru.playground", "com.playground.security"})
@EntityScan({"ru.playground", "com.playground.security"})
public class PlaygroundApplication {

    public static void main(String[] args) {
        SpringApplication.run(PlaygroundApplication.class, args);
    }
}
