package com.playground.security.config;

import java.nio.file.Path;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {
    private final AppProperties properties;

    public WebConfig(AppProperties properties) {
        this.properties = properties;
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins(properties.cors().allowedOrigins().toArray(String[]::new))
                .allowedMethods("GET", "POST", "OPTIONS")
                .allowedHeaders("Accept", "Content-Type", "X-Ingest-Token");
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        Path mediaDirectory = Path.of(properties.media().directory())
                .toAbsolutePath()
                .normalize();
        registry.addResourceHandler("/media/**")
                .addResourceLocations(mediaDirectory.toUri().toString() + "/");
    }
}
