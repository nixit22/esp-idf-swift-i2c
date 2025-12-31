// Copyright (c) 2026 Nicolas Christe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@_exported import ESP_I2C
import Platform

public final class I2CMasterBus {
    private let busHandle: i2c_master_bus_handle_t

    public init?(
        sda_io_num: gpio_num_t = GPIO_NUM_4,
        scl_io_num: gpio_num_t = GPIO_NUM_5,
        clk_config: i2c_clock_source_t = I2C_CLK_SRC_DEFAULT
    ) {
        var busConfig = i2c_master_bus_config_t(
            i2c_port: i2c_port_num_t(I2C_NUM_0.rawValue),
            sda_io_num: sda_io_num,
            scl_io_num: scl_io_num,
            .init(clk_source: clk_config),
            glitch_ignore_cnt: 7,
            intr_priority: 0,
            trans_queue_depth: 0,
            flags: .init(enable_internal_pullup: 1, allow_pd: 0))

        var busHandle: i2c_master_bus_handle_t?
        if i2c_new_master_bus(&busConfig, &busHandle) != ESP_OK {
            return nil
        }
        guard let busHandle else { return nil }
        self.busHandle = busHandle
    }

    func delete() -> esp_err_t {
        return i2c_del_master_bus(busHandle)
    }

    func addDevice(
        device_address: UInt16,
        scl_speed_hz: UInt32 = 100_000,
        dev_addr_length: i2c_addr_bit_len_t = I2C_ADDR_BIT_LEN_7
    ) -> Device? {
        var deviceConfig = i2c_device_config_t(
            dev_addr_length: dev_addr_length,
            device_address: device_address,
            scl_speed_hz: scl_speed_hz,
            scl_wait_us: 0,
            flags: .init(disable_ack_check: 0))

        var deviceHandle: i2c_master_dev_handle_t?
        if i2c_master_bus_add_device(busHandle, &deviceConfig, &deviceHandle) != ESP_OK {
            return nil
        }
        guard let deviceHandle else { return nil }
        return Device(deviceHandle: deviceHandle)
    }

    public final class Device {
        private let deviceHandle: i2c_master_dev_handle_t

        init(deviceHandle: i2c_master_dev_handle_t) {
            self.deviceHandle = deviceHandle
        }

        func transmit(data: ContiguousArray<UInt8>, timeout: Int32 = -1) -> esp_err_t {
            data.withUnsafeBufferPointer { buffer in
                i2c_master_transmit(deviceHandle, buffer.baseAddress, data.count, timeout)
            }
        }

        func receive(length: Int, timeout: Int32 = -1) -> (esp_err_t, ContiguousArray<UInt8>?) {
            var buffer = ContiguousArray<UInt8>(repeating: 0, count: length)
            let result = buffer.withUnsafeMutableBufferPointer { ptr in
                i2c_master_receive(deviceHandle, ptr.baseAddress, length, timeout)
            }
            return (result, buffer)
        }

        func transmitReceive(
            transmitData: ContiguousArray<UInt8>,
            receiveLength: Int,
            timeout: Int32 = -1
        ) -> (esp_err_t, ContiguousArray<UInt8>?) {
            var receiveBuffer = ContiguousArray<UInt8>(repeating: 0, count: receiveLength)
            let result = transmitData.withUnsafeBufferPointer { txPtr in
                receiveBuffer.withUnsafeMutableBufferPointer { rxPtr in
                    i2c_master_transmit_receive(
                        deviceHandle,
                        txPtr.baseAddress, transmitData.count,
                        rxPtr.baseAddress, receiveLength,
                        timeout)
                }
            }
            return (result, receiveBuffer)
        }

        func remove() -> esp_err_t {
            return i2c_master_bus_rm_device(deviceHandle)
        }
    }
}