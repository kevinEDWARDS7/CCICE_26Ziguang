#ifndef _H_RKNN_OBJ_DETECTOR_H_
#define _H_RKNN_OBJ_DETECTOR_H_

#include <opencv2/opencv.hpp>
#include "rknn_api.h"
#include "common.h"

#include "file_utils.h"
#include "image_utils.h"

#define OBJ_NAME_MAX_SIZE 64
#define OBJ_NUMB_MAX_SIZE 128
#define OBJ_CLASS_NUM 80
#define NMS_THRESH 0.45
#define BOX_THRESH 0.25

struct DetectionResult
{
    cv::Rect rect;
    int classid;
    float score = 0;
    DetectionResult(){
    }
};//识别结果

typedef struct {
    image_rect_t box;
    float prop;
    int cls_id;
} object_detect_result;

typedef struct {
    int id;
    int count;
    object_detect_result results[OBJ_NUMB_MAX_SIZE];
} object_detect_result_list;

typedef struct {
    rknn_context rknn_ctx;
    rknn_input_output_num io_num;
    rknn_tensor_attr* input_attrs;
    rknn_tensor_attr* output_attrs;

    int model_channel;
    int model_width;
    int model_height;
    bool is_quant;
} rknn_app_context_t;

static char *class_labels[OBJ_CLASS_NUM]={
        "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck",
        "boat", "traffic light", "fire hydrant", "stop sign", "parking meter", "bench",
        "bird", "cat", "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra",
        "giraffe", "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee",
        "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove",
        "skateboard", "surfboard", "tennis racket", "bottle", "wine glass", "cup",
        "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich", "orange",
        "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
        "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse",
        "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
        "refrigerator", "book", "clock", "vase", "scissors", "teddy bear", "hair drier",
        "toothbrush"
};

//static char *class_labels[OBJ_CLASS_NUM]={"biao_screen","yu_smoke","zhang_liu_elb","zhao_drink","zhao_screen"};

class RknnObjectDetector {
public:
    RknnObjectDetector();
    ~RknnObjectDetector();

    int InitResource(const char *model_path);
    int Process(cv::Mat& image, std::vector<DetectionResult>& result_out);
    char *getClassName(int cls_id);

private:
    int init_model(const char *model_path, rknn_app_context_t *app_ctx);
    int inference_model(rknn_app_context_t *app_ctx, image_buffer_t *img, object_detect_result_list *od_results);
    int post_process(rknn_app_context_t *app_ctx, void *outputs, letterbox_t *letter_box, float conf_threshold, float nms_threshold, object_detect_result_list *od_results);


    static int process_i8(int8_t *box_tensor, int32_t box_zp, float box_scale,
                          int8_t *score_tensor, int32_t score_zp, float score_scale,
                          int8_t *score_sum_tensor, int32_t score_sum_zp, float score_sum_scale,
                          int grid_h, int grid_w, int stride, int dfl_len,
                          std::vector<float> &boxes,
                          std::vector<float> &objProbs,
                          std::vector<int> &classId,
                          float threshold);

    static int process_fp32(float *box_tensor, float *score_tensor, float *score_sum_tensor,
                            int grid_h, int grid_w, int stride, int dfl_len,
                            std::vector<float> &boxes,
                            std::vector<float> &objProbs,
                            std::vector<int> &classId,
                            float threshold);

    static int quick_sort_indice_inverse(std::vector<float> &input, int left, int right, std::vector<int> &indices);
    static float CalculateOverlap(float xmin0, float ymin0, float xmax0, float ymax0, float xmin1, float ymin1, float xmax1,
                                  float ymax1);



    static void compute_dfl(float* tensor, int dfl_len, float* box);
    static int nms(int validCount, std::vector<float> &outputLocations, std::vector<int> classIds, std::vector<int> &order,
                   int filterId, float threshold);

    static void dump_tensor_attr(rknn_tensor_attr *attr);
    int release_model(rknn_app_context_t *app_ctx);
    inline static int32_t __clip(float val, float min, float max)
    {
        float f = val <= min ? min : (val >= max ? max : val);
        return f;
    }

    inline static int clamp(float val, int min, int max) { return val > min ? (val < max ? val : max) : min; }


    rknn_app_context_t rknn_app_ctx;
};


#endif //RKNN_OBJ_DETECTOR_H

