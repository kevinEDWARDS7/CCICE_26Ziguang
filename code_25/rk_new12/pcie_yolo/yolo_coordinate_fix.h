// YOLO坐标转换修复方案
// 修改yolov11_detector.cpp中的post_process函数

// 在post_process函数中添加调试信息和坐标验证
int YOLOv11Detector::post_process(rknn_app_context_t *app_ctx, void *outputs, letterbox_t *letter_box, float conf_threshold, float nms_threshold, object_detect_result_list *od_results)
{
    rknn_output *_outputs = (rknn_output *)outputs;

    std::vector<float> filterBoxes;
    std::vector<float> objProbs;
    std::vector<int> classId;
    int validCount = 0;
    int stride = 0;
    int grid_h = 0;
    int grid_w = 0;
    int model_in_w = app_ctx->model_width;
    int model_in_h = app_ctx->model_height;

    memset(od_results, 0, sizeof(object_detect_result_list));

    // 添加调试信息
    printf("模型输入尺寸: %dx%d\n", model_in_w, model_in_h);
    printf("letterbox参数: scale=%.3f, x_pad=%d, y_pad=%d\n", 
           letter_box->scale, letter_box->x_pad, letter_box->y_pad);

    // ... 原有的处理逻辑 ...

    // 在坐标转换部分添加验证
    for (int i = 0; i < validCount; ++i)
    {
        if (indexArray[i] == -1 || last_count >= OBJ_NUMB_MAX_SIZE)
        {
            continue;
        }
        int n = indexArray[i];

        float x1 = filterBoxes[n * 4 + 0] - letter_box->x_pad;
        float y1 = filterBoxes[n * 4 + 1] - letter_box->y_pad;
        float x2 = x1 + filterBoxes[n * 4 + 2];
        float y2 = y1 + filterBoxes[n * 4 + 3];
        int id = classId[n];
        float obj_conf = objProbs[i];

        // 添加坐标验证和调试
        printf("原始坐标: x1=%.2f, y1=%.2f, x2=%.2f, y2=%.2f\n", x1, y1, x2, y2);
        printf("letterbox偏移: x_pad=%d, y_pad=%d, scale=%.3f\n", 
               letter_box->x_pad, letter_box->y_pad, letter_box->scale);

        // 确保坐标在合理范围内
        x1 = fmax(0, fmin(x1, model_in_w));
        y1 = fmax(0, fmin(y1, model_in_h));
        x2 = fmax(0, fmin(x2, model_in_w));
        y2 = fmax(0, fmin(y2, model_in_h));

        od_results->results[last_count].box.left = (int)(x1 / letter_box->scale);
        od_results->results[last_count].box.top = (int)(y1 / letter_box->scale);
        od_results->results[last_count].box.right = (int)(x2 / letter_box->scale);
        od_results->results[last_count].box.bottom = (int)(y2 / letter_box->scale);
        od_results->results[last_count].prop = obj_conf;
        od_results->results[last_count].cls_id = id;

        // 添加最终坐标验证
        printf("最终坐标: left=%d, top=%d, right=%d, bottom=%d\n",
               od_results->results[last_count].box.left,
               od_results->results[last_count].box.top,
               od_results->results[last_count].box.right,
               od_results->results[last_count].box.bottom);

        last_count++;
    }
    od_results->count = last_count;
    return 0;
}

