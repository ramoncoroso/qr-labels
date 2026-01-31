import CanvasDesigner from "./canvas_designer"
import CodeGenerator from "./code_generator"
import ExcelReader from "./excel_reader"
import PrintEngine from "./print_engine"
import LabelPreview from "./label_preview"
import KeyboardShortcuts from "./keyboard_shortcuts"
import SortableLayers from "./sortable_layers"
import SingleLabelPrint from "./single_label_print"
import DraggableElements from "./draggable_elements"
import AutoHideFlash from "./auto_hide_flash"
import AutoUploadSubmit from "./auto_upload_submit"

const Hooks = {
  CanvasDesigner,
  CodeGenerator,
  ExcelReader,
  PrintEngine,
  LabelPreview,
  KeyboardShortcuts,
  SortableLayers,
  SingleLabelPrint,
  DraggableElements,
  AutoHideFlash,
  AutoUploadSubmit
}

export default Hooks
