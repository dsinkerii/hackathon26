package com.playground.security.dto;

import com.playground.security.entity.Person;
import java.time.OffsetDateTime;

public record PersonResponse(
        String id,
        String status,
        OffsetDateTime firstSeenAt,
        String displayName,
        int visitCount,
        String photoUrl) {
    public static PersonResponse from(Person person) {
        return new PersonResponse(
                person.getId(),
                person.getStatus().name(),
                person.getFirstSeenAt(),
                person.getDisplayName(),
                person.getVisitCount(),
                person.getPhotoUrl());
    }
}
