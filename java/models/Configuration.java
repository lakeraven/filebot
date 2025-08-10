package com.lakeraven.filebot.core.models;

import java.util.Map;
import java.util.HashMap;

/**
 * Configuration holder for adapter settings
 */
public class Configuration {
    
    private Map<String, Object> properties;
    
    public Configuration() {
        this.properties = new HashMap<>();
    }
    
    public Configuration(Map<String, Object> properties) {
        this.properties = new HashMap<>(properties);
    }
    
    /**
     * Get string property with default value
     * @param key Property key
     * @param defaultValue Default value if key not found
     * @return Property value or default
     */
    public String getString(String key, String defaultValue) {
        Object value = properties.get(key);
        return value != null ? value.toString() : defaultValue;
    }
    
    /**
     * Get string property
     * @param key Property key
     * @return Property value or null
     */
    public String getString(String key) {
        return getString(key, null);
    }
    
    /**
     * Get integer property with default value
     * @param key Property key
     * @param defaultValue Default value if key not found
     * @return Property value or default
     */
    public int getInt(String key, int defaultValue) {
        Object value = properties.get(key);
        if (value instanceof Number) {
            return ((Number) value).intValue();
        }
        try {
            return Integer.parseInt(value.toString());
        } catch (NumberFormatException | NullPointerException e) {
            return defaultValue;
        }
    }
    
    /**
     * Get boolean property with default value
     * @param key Property key
     * @param defaultValue Default value if key not found
     * @return Property value or default
     */
    public boolean getBoolean(String key, boolean defaultValue) {
        Object value = properties.get(key);
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        if (value != null) {
            return Boolean.parseBoolean(value.toString());
        }
        return defaultValue;
    }
    
    /**
     * Check if configuration has a key
     * @param key Property key
     * @return True if key exists
     */
    public boolean hasKey(String key) {
        return properties.containsKey(key);
    }
    
    /**
     * Set property value
     * @param key Property key
     * @param value Property value
     */
    public void setProperty(String key, Object value) {
        properties.put(key, value);
    }
    
    /**
     * Get all properties
     * @return Map of all properties
     */
    public Map<String, Object> getProperties() {
        return new HashMap<>(properties);
    }
}