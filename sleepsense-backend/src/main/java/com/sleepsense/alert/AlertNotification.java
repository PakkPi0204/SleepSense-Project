package com.sleepsense.alert;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** One push notification about one critical factor. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AlertNotification {
    private String deviceId;
    private String factor;
    private Double value;
    private Double threshold;
    private String title;
    private String message;
}
