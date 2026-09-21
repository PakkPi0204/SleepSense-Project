package com.sleepsense.alert;

import com.sleepsense.analysis.ThresholdResult;
import com.sleepsense.model.SensorData;

import java.util.List;

/**
 * Delivers critical-room alerts to the user's mobile device.
 *
 * <p>Test Plan reference: {@code sendAlert()} in ITC-01 and STC-05. Declared as
 * an interface so the integration test can substitute a Mockito mock and assert
 * on the number of invocations.
 */
public interface AlertDispatcher {

    /**
     * Called once per pipeline run that finds at least one critical factor.
     *
     * @return the notifications that were sent — one per critical factor, which
     *         is what STC-05 TC-03 expects when CO2 and noise go critical at the
     *         same time.
     */
    List<AlertNotification> sendAlert(String deviceId, SensorData reading, ThresholdResult result);
}
