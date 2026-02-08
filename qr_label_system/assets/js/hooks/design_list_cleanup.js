/**
 * DesignListCleanup Hook
 * Mounted on the designs index page to handle IndexedDB cleanup when a design is deleted.
 */
import { clearDataset } from './data_store'

const DesignListCleanup = {
  mounted() {
    this.handleEvent("clear_dataset", ({ user_id, design_id }) => {
      clearDataset(user_id, design_id)
    })
  }
}

export default DesignListCleanup
