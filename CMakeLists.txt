idf_component_register(
    SRCS 
        I2CMaster.swift
        i2c.c
    INCLUDE_DIRS "."
    REQUIRES esp_driver_i2c SwiftPlatform
)

swift_configure_component("I2C")
