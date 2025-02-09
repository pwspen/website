class NoteStore {
    private count: number = 0;
  
    increment() {
      this.count += 1;
      return this.count;
    }
  
    reset() {
      this.count = 0;
    }
  }
  
  export const noteStore = new NoteStore();