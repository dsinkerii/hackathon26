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
        String[] origins = properties.cors().allowedOrigins().toArray(String[]::new);
        for (String path : new String[] {"/api/**", "/media/**"}) {
            registry.addMapping(path)
                    .allowedOrigins(origins)
                    .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
                    .allowedHeaders("Accept", "Authorization", "Content-Type", "X-Ingest-Token");
        }
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
