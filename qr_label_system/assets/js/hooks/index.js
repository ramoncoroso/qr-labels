import CanvasDesigner from "./canvas_designer"
import CodeGenerator from "./code_generator"
import DataFileReader from "./data_file_reader"
import PrintEngine from "./print_engine"
import LabelPreview from "./label_preview"
import KeyboardShortcuts from "./keyboard_shortcuts"

import SingleLabelPrint from "./single_label_print"
import DraggableElements from "./draggable_elements"
import DesignListCleanup from "./design_list_cleanup"
import AutoHideFlash from "./auto_hide_flash"
import AutoUploadSubmit from "./auto_upload_submit"
import PropertyFields from "./property_fields"
import BorderRadiusSlider from "./border_radius_slider"
import ScrollTo from "./scroll_to"
import QRLogoUpload from "./qr_logo_upload"

const Hooks = {
  CanvasDesigner,
  CodeGenerator,
  DataFileReader,
  PrintEngine,
  LabelPreview,
  KeyboardShortcuts,

  SingleLabelPrint,
  DraggableElements,
  DesignListCleanup,
  AutoHideFlash,
  AutoUploadSubmit,
  PropertyFields,
  BorderRadiusSlider,
  ScrollTo,
  QRLogoUpload
}

export default Hooks
