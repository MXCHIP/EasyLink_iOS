

#ifndef EMWHeader_h
#define EMWHeader_h

#define iPHONE_VIEW_WIDTH                                             320.0


#define SECTION_HEADER_WIDTH                                        300.0
#define ZERO_X                                                                  0.0
#define ZERO_Y                                                                  0.0


#define TABLEVIEW_HEIGHT                                               231.0
#define TABLEVIEW_REDUCED_HEIGHT                                 195.0
#define TABLEVIEW_OFFSET                                               120.0

/// table rows
#define DHCP_ROW                                                            0
#define LOCAL_IP_ROW                                                        1
#define NETMASK_ROW                                                       2
#define GATEWAY_ROW                                                      3
#define DNS_ROW                                                     4



#define SSID_ROW                                                               0
#define PASSWORD_ROW                                                      1
#define USER_INFO_ROW                                       2
#define IP_ADDRESS_ROW                                                                3
#define DEVICE_NAME_ROW                                                  4

#define SECTION_HEIGHT                                                   30.0

#define SECTION_HEADER_LABEL_X                                    10.0
#define SECTION_HEADER_LABEL_Y                                    15.0
#define SECTION_HEADER_LABEL_HEIGHT                            20.0
#define SECTION_HEADER_LABEL_iPAD_X                            50.0


// Textfield placement constants.
#define CELL_IPHONE_FIELD_X                                            130.0
#define CELL_iPHONE_FIELD_Y                                            8.0
#define CELL_iPHONE_FIELD_WIDTH                                     170.0
#define CELL_iPHONE_FIELD_HEIGHT                                    30.0

// Textfield placement constants.
#define CELL_IPHONE_SWITCH_X                                            251.0
#define CELL_iPHONE_SWITCH_Y                                            6.0
#define CELL_iPHONE_SWITCH_WIDTH                                     60.0
#define CELL_iPHONE_SWITCH_HEIGHT                                    30.0


// Group Id overlay view border constants.
#define GROUP_ID_VIEW_X                                                  0.0
#define GROUP_ID_VIEW_Y                                                 44.0
#define GROUP_ID_VIEW_WIDTH                                          320.0
#define GROUP_ID_VIEW_HEIGHT                                         416.0

#define GROUP_ID_VIEW_TAG                                              1000


// iPad constants.

#define iPAD_TABLE_BACKVIEW_X                                      0.0
#define iPAD_TABLE_BACKVIEW_Y                                      0.0
#define iPAD_TABLE_BACKVIEW_WIDTH                               768.0
#define iPAD_TABLE_BACKVIEW_HEIGHT                              175.0

/// GID Switch constant
#define GID_SWITCH_PORTRAITE_X                                      258.0
#define GID_SWITCH_Y                                                       473.0
#define GID_SWITCH_WIDTH                                                79.0
#define GID_SWITCH_HEIGHT                                               27.0

#define GID_SWITCH_LANDSCAPE_X                                     408.0

/// GID Button constant
#define GID_BUTTON_PORTRAITE_X                                     434.0
#define GID_BUTTON_Y                                                      462.0
#define GID_BUTTON_WIDTH                                               77.0
#define GID_BUTTON_HEIGHT                                               50.0

#define GID_BUTTON_LANDSCAPE_X                                    584.0

/// [x]cube logo button
#define xcubeLOGO_BUTTON_X                                            0.0
#define xcubeLOGO_BUTTON_PORTRAITE_Y                            960.0
#define xcubeLOGO_BUTTON_LANDSCAPE_Y                           704.0
#define xcubeLOGO_BUTTON_PORTRAITE_WIDTH                      768.0
#define xcubeLOGO_BUTTON_LANDSCAPE_WIDTH                     1024.0
#define xcubeLOGO_BUTTON_HEIGHT                                        44.0

///// rotation spinner view frame 
#define SPINNER_VIEW_PORTRAITE_X                                       699.0
#define SPINNER_VIEW_PORTRAITE_Y                                       557.0
#define SPINNER_VIEW_LANDSCAPE_X                                     955.0
#define SPINNER_VIEW_WIDTH                                                  26.0
#define SPINNER_VIEW_HEIGHT                                                 26.0

//// key character maximum limit
#define KEY_CHARACTER_MAXIMUM_LIMIT                                  16

//// text field frame

#define PORTRAITE_TEXT_FIELD_FRAME                                  CGRectMake(300.0, 8.0, 350.0, 30.0)
#define LANDSCAPE_TEXT_FIELD_FRAME                                 CGRectMake(300.0, 8.0, 600.0, 30.0)

// Scan QR Code button frame
#define SCAN_QR_BUTTON_PORTRAITE_FRAME                         CGRectMake(717.0, 8.0, 31.0, 28.0)
#define SCAN_QR_BUTTON_LANDSCAPE_FRAME                        CGRectMake(973.0, 8.0, 31.0, 28.0)

#define TOOL_BAR_PORTRAITE_FRAME                                    CGRectMake(0.0, 980.0, 768.0, 44.0)
#define TOOL_BAR_LANDSCAPE_FRAME                                    CGRectMake(0.0, 724.0, 1024.0, 44.0)
#endif
