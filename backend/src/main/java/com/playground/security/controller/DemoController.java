package com.playground.security.controller;

import com.playground.security.service.DemoDataService;
import java.util.Map;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Demo helpers. The whole controller is created only when {@code DEMO_MODE=true}
 * (app.demo.enabled), so it never exists in a normal deployment.
 */
@RestController
@RequestMapping("/api/v1/demo")
@ConditionalOnProperty(prefix = "app.demo", name = "enabled", havingValue = "true")
public class DemoController {
    private final DemoDataService demoData;

    public DemoController(DemoDataService demoData) {
        this.demoData = demoData;
    }

    /** Wipes the journals and seeds a small dataset for the showcase run. */
    @PostMapping("/reset")
    public Map<String, Long> reset() {
        DemoDataService.Counts counts = demoData.reset();
        return Map.of(
                "incidents", counts.incidents(),
                "persons", counts.persons());
    }
}
